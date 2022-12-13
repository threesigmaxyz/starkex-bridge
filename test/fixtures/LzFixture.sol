// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { LzEndpointMock } from "test/mocks/lz/LzEndpointMock.sol";

import { IAccessControlFacet } from "src/interfaces/IAccessControlFacet.sol";

import { LzReceptor } from "src/interoperability/LzReceptor.sol";
import { LzTransmitter } from "src/interoperability/LzTransmitter.sol";

// TODO move to interoperability/interfaces
interface IStarkEx {
    function getValidiumVaultRoot() external view returns (uint256);
    function getValidiumTreeHeight() external view returns (uint256);
    function getRollupVaultRoot() external view returns (uint256);
    function getRollupTreeHeight() external view returns (uint256);
    function getOrderRoot() external view returns (uint256);
    function getOrderTreeHeight() external view returns (uint256);
    function getSequenceNumber() external view returns (uint256);
}

contract LzFixture is BaseFixture {
    //==============================================================================//
    //=== Constants                                                              ===//
    //==============================================================================//

    address public constant STARKEX_ADDRESS = 0xF5C9F957705bea56a7e806943f98F7777B995826;
    uint16 public constant MOCK_CHAIN_ID = 1337;

    uint256 public STARKEX_MOCK_VALIDIUM_VAULT_ROOT  = 111;
    uint256 public STARKEX_MOCK_VALIDIUM_TREE_HEIGHT = 31;
    uint256 public STARKEX_MOCK_ROLLUP_VAULT_ROOT    = 222;
    uint256 public STARKEX_MOCK_ROLLUP_TREE_HEIGHT   = 31;
    uint256 public STARKEX_MOCK_ORDER_ROOT           = 333;
    uint256 public STARKEX_MOCK_ORDER_TREE_HEIGHT    = 31;
    uint256 public STARKEX_MOCK_SEQUENCE_NUMBER      = 314;

    //==============================================================================//
    //=== State Variables                                                        ===//
    //==============================================================================//

    LzEndpointMock lzEndpoint;
    LzTransmitter transmitter;
    LzReceptor receptor;
    
    //==============================================================================//
    //=== Setup                                                                  ===//
    //==============================================================================//

    function setUp() public override {
        super.setUp();

        // Deploy mocked Layer Zero endpoint
        lzEndpoint = new LzEndpointMock(MOCK_CHAIN_ID);

        // Deploy transmitter interoperability contract
        vm.prank(_owner());
        transmitter = new LzTransmitter(address(lzEndpoint), STARKEX_ADDRESS);

        // Deploy receptor interoperability contract
        vm.prank(_owner());
        receptor = new LzReceptor(address(lzEndpoint), bridge);

        // Whitelist receptor as brige interoperability contract
        vm.prank(_owner());
        IAccessControlFacet(bridge).setInteroperabilityContract(address(receptor));

        // Register interoperability contracts on Layer Zero
        lzEndpoint.setDestLzEndpoint(address(transmitter), address(lzEndpoint));
        lzEndpoint.setDestLzEndpoint(address(receptor), address(lzEndpoint));

        // Set trusted Layer Zero remote
        vm.startPrank(_owner());
        transmitter.setTrustedRemote(MOCK_CHAIN_ID, abi.encodePacked(address(receptor), address(transmitter)));
        receptor.setTrustedRemote(MOCK_CHAIN_ID, abi.encodePacked(address(transmitter), address(receptor)));
        vm.stopPrank();

        // Setup global mocks
        _setUpMocks();
    }

    function _setUpMocks() internal {
        vm.mockCall(
            STARKEX_ADDRESS,
            abi.encodeWithSelector(IStarkEx.getValidiumVaultRoot.selector),
            abi.encode(STARKEX_MOCK_VALIDIUM_VAULT_ROOT)
        );

        vm.mockCall(
            STARKEX_ADDRESS,
            abi.encodeWithSelector(IStarkEx.getValidiumTreeHeight.selector),
            abi.encode(STARKEX_MOCK_VALIDIUM_TREE_HEIGHT)
        );

        vm.mockCall(
            STARKEX_ADDRESS,
            abi.encodeWithSelector(IStarkEx.getRollupVaultRoot.selector),
            abi.encode(STARKEX_MOCK_ROLLUP_VAULT_ROOT)
        );

        vm.mockCall(
            STARKEX_ADDRESS,
            abi.encodeWithSelector(IStarkEx.getRollupTreeHeight.selector),
            abi.encode(STARKEX_MOCK_ROLLUP_TREE_HEIGHT)
        );

        vm.mockCall(
            STARKEX_ADDRESS,
            abi.encodeWithSelector(IStarkEx.getOrderRoot.selector),
            abi.encode(STARKEX_MOCK_ORDER_ROOT)
        );

        vm.mockCall(
            STARKEX_ADDRESS,
            abi.encodeWithSelector(IStarkEx.getOrderTreeHeight.selector),
            abi.encode(STARKEX_MOCK_ORDER_TREE_HEIGHT)
        );

        vm.mockCall(
            STARKEX_ADDRESS,
            abi.encodeWithSelector(IStarkEx.getSequenceNumber.selector),
            abi.encode(STARKEX_MOCK_SEQUENCE_NUMBER)
        );
    }
}