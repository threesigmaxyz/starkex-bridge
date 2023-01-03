// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { LzEndpointMock } from "test/mocks/lz/LzEndpointMock.sol";

import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

import { LzReceptor } from "src/interoperability/LzReceptor.sol";
import { LzTransmitter } from "src/interoperability/LzTransmitter.sol";

import { IStarkEx } from "src/interfaces/interoperability/IStarkEx.sol";

import { AccessControlFacet } from "src/facets/AccessControlFacet.sol";
import { DepositFacet } from "src/facets/DepositFacet.sol";
import { DiamondCutFacet } from "src/facets/DiamondCutFacet.sol";
import { TokenRegisterFacet } from "src/facets/TokenRegisterFacet.sol";
import { WithdrawalFacet } from "src/facets/WithdrawalFacet.sol";
import { StateFacet } from "src/facets/StateFacet.sol";
import { ERC165Facet } from "src/facets/ERC165Facet.sol";

import "@forge-std/Test.sol";

contract LzFixture is BaseFixture {
    //==============================================================================//
    //=== Constants                                                              ===//
    //==============================================================================//

    address public constant STARKEX_ADDRESS = 0xF5C9F957705bea56a7e806943f98F7777B995826;
    uint16 public constant MOCK_CHAIN_ID = 1337;
    uint16 public constant MOCK_CHAIN_ID_SIDECHAIN_1 = 1338;
    uint16 public constant MOCK_CHAIN_ID_SIDECHAIN_2 = 1339;

    uint256 public STARKEX_MOCK_ORDER_ROOT = 333;
    uint256 public STARKEX_MOCK_SEQUENCE_NUMBER = 314;

    //==============================================================================//
    //=== State Variables                                                        ===//
    //==============================================================================//

    LzEndpointMock _lzEndpoint;
    LzEndpointMock _lzEndpointSideChain1;
    LzEndpointMock _lzEndpointSideChain2;
    LzTransmitter _transmitter;
    LzReceptor _receptorSideChain1;
    LzReceptor _receptorSideChain2;
    address _bridgeSideChain1;
    address _bridgeSideChain2;

    //==============================================================================//
    //=== Setup                                                                  ===//
    //==============================================================================//

    function setUp() public override {
        super.setUp();

        // There are 2 bridges now, so the first bridge is the one from the base fixture.
        _bridgeSideChain1 = _bridge;

        // Label the keeper.
        vm.label(_keeper(), "keeper");

        // Deploy the other bridge to the other side chain.
        Facets memory facets_;

        facets_.accessControl = address(new AccessControlFacet());
        facets_.deposit = address(new DepositFacet());
        facets_.diamondCut = address(new DiamondCutFacet());
        facets_.tokenRegister = address(new TokenRegisterFacet());
        facets_.withdrawal = address(new WithdrawalFacet());
        facets_.state = address(new StateFacet());
        facets_.erc165 = address(new ERC165Facet());

        vm.startPrank(_owner());
        // Deploy bridges to side chains.
        _bridgeSideChain2 = _deployBridge(_owner(), facets_);

        // Deploy mocked Layer Zero endpoint.
        _lzEndpoint = new LzEndpointMock(MOCK_CHAIN_ID);
        _lzEndpointSideChain1 = new LzEndpointMock(MOCK_CHAIN_ID_SIDECHAIN_1);
        _lzEndpointSideChain2 = new LzEndpointMock(MOCK_CHAIN_ID_SIDECHAIN_2);

        // Deploy _transmitter interoperability contract.
        _transmitter = new LzTransmitter(address(_lzEndpoint), STARKEX_ADDRESS);

        // Deploy _receptor interoperability contract
        _receptorSideChain1 = new LzReceptor(address(_lzEndpointSideChain1), _bridgeSideChain1);
        _receptorSideChain2 = new LzReceptor(address(_lzEndpointSideChain2), _bridgeSideChain2);

        _setPendingRoles(_bridgeSideChain1, address(_receptorSideChain1));
        _setPendingRoles(_bridgeSideChain2, address(_receptorSideChain2));

        vm.stopPrank();

        _acceptPendingRoles(_bridgeSideChain2);

        // These ones must be accepted separately.
        _receptorSideChain1.acceptBridgeRole();
        _receptorSideChain2.acceptBridgeRole();

        vm.startPrank(_owner());

        // Register interoperability contracts on Layer Zero.
        _connectTransmitterReceptor(
            _lzEndpoint,
            _lzEndpointSideChain1,
            MOCK_CHAIN_ID,
            MOCK_CHAIN_ID_SIDECHAIN_1,
            _receptorSideChain1,
            _transmitter
        );
        _connectTransmitterReceptor(
            _lzEndpoint,
            _lzEndpointSideChain2,
            MOCK_CHAIN_ID,
            MOCK_CHAIN_ID_SIDECHAIN_2,
            _receptorSideChain2,
            _transmitter
        );

        vm.stopPrank();
    }

    function _connectTransmitterReceptor(
        LzEndpointMock lzEndpoint_,
        LzEndpointMock _lzEndpointSideChain,
        uint16 mainChainId_,
        uint16 sideChainId_,
        LzReceptor receptor_,
        LzTransmitter transmitter_
    ) internal {
        lzEndpoint_.setDestLzEndpoint(address(receptor_), address(_lzEndpointSideChain));
        transmitter_.setTrustedRemote(sideChainId_, abi.encodePacked(address(receptor_), address(_transmitter)));
        receptor_.setTrustedRemote(mainChainId_, abi.encodePacked(address(transmitter_), address(receptor_)));
    }

    function _keeper() internal pure returns (address) {
        return vm.addr(978);
    }
}
