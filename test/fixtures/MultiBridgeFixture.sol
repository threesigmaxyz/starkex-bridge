// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LzEndpointMock } from "test/mocks/lz/LzEndpointMock.sol";

import { BaseFixture } from "test/fixtures/BaseFixture.sol";

import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

import { LzReceptor } from "src/interoperability/LzReceptor.sol";
import { LzTransmitter } from "src/interoperability/LzTransmitter.sol";

import { MultiBridgeReceptor } from "src/interoperability/MultiBridgeReceptor.sol";
import { MultiBridgeTransmitter } from "src/interoperability/MultiBridgeTransmitter.sol";

import { IStarkEx } from "src/interfaces/interoperability/IStarkEx.sol";

import { LibDeployBridge } from "common/LibDeployBridge.sol";

contract MultiBridgeFixture is BaseFixture {
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
    LzTransmitter _lzTransmitter;
    LzReceptor _lzReceptorSideChain1;
    LzReceptor _lzReceptorSideChain2;

    MultiBridgeTransmitter _transmitter;
    MultiBridgeReceptor _receptorSideChain1;
    MultiBridgeReceptor _receptorSideChain2;

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

        vm.startPrank(_owner());
        // Deploy bridges to side chains.
        _bridgeSideChain2 = LibDeployBridge.deployBridge(_owner());

        // Deploy Multi-Bridge transmitter and receptor interoperability contracts.
        _transmitter = new MultiBridgeTransmitter(STARKEX_ADDRESS);
        _receptorSideChain1 = new MultiBridgeReceptor(_bridgeSideChain1);
        _receptorSideChain2 = new MultiBridgeReceptor(_bridgeSideChain2);

        _receptorSideChain1.updateThreshold(50);
        _receptorSideChain2.updateThreshold(50);

        _setPendingRoles(_bridgeSideChain1, address(_receptorSideChain1));
        _setPendingRoles(_bridgeSideChain2, address(_receptorSideChain2));

        vm.stopPrank();

        _acceptPendingRoles(_bridgeSideChain2);

        // These ones must be accepted separately.
        _receptorSideChain1.acceptBridgeRole();
        _receptorSideChain2.acceptBridgeRole();

        // Deploy Layer Zero and add to Multi-Bridge.
        _deploy_LayerZero(10);
    }

    function _deploy_LayerZero(uint32 weight_) internal {
        vm.startPrank(_owner());

        // Deploy mocked Layer Zero endpoint.
        _lzEndpoint = new LzEndpointMock(MOCK_CHAIN_ID);
        _lzEndpointSideChain1 = new LzEndpointMock(MOCK_CHAIN_ID_SIDECHAIN_1);
        _lzEndpointSideChain2 = new LzEndpointMock(MOCK_CHAIN_ID_SIDECHAIN_2);

        // Deploy Layer Zero transmitter and receptor interoperability contracts.
        _lzTransmitter = new LzTransmitter(address(_lzEndpoint));
        _lzReceptorSideChain1 = new LzReceptor(address(_lzEndpointSideChain1), address(_receptorSideChain1));
        _lzReceptorSideChain2 = new LzReceptor(address(_lzEndpointSideChain2), address(_receptorSideChain2));

        // Set Layer Zero as a bridge in Multi-Bridge contracts.
        _transmitter.addBridge(address(_lzTransmitter));
        _receptorSideChain1.updateBridgeWeight(address(_lzReceptorSideChain1), weight_);
        _receptorSideChain2.updateBridgeWeight(address(_lzReceptorSideChain2), weight_);

        // Register interoperability contracts on Layer Zero.
        _connectTransmitterReceptor(
            _lzEndpoint,
            _lzEndpointSideChain1,
            MOCK_CHAIN_ID,
            MOCK_CHAIN_ID_SIDECHAIN_1,
            _lzReceptorSideChain1,
            _lzTransmitter
        );
        _connectTransmitterReceptor(
            _lzEndpoint,
            _lzEndpointSideChain2,
            MOCK_CHAIN_ID,
            MOCK_CHAIN_ID_SIDECHAIN_2,
            _lzReceptorSideChain2,
            _lzTransmitter
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
