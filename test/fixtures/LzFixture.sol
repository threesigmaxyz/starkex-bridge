// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { LzEndpointMock } from "test/mocks/lz/LzEndpointMock.sol";

import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

import { LzReceptor } from "src/interoperability/LzReceptor.sol";
import { LzTransmitter } from "src/interoperability/LzTransmitter.sol";

import { IStarkEx } from "src/interfaces/interoperability/IStarkEx.sol";

contract LzFixture is BaseFixture {
    //==============================================================================//
    //=== Constants                                                              ===//
    //==============================================================================//

    address public constant STARKEX_ADDRESS = 0xF5C9F957705bea56a7e806943f98F7777B995826;
    uint16 public constant MOCK_CHAIN_ID = 1337;

    uint256 public STARKEX_MOCK_ORDER_ROOT = 333;
    uint256 public STARKEX_MOCK_SEQUENCE_NUMBER = 314;

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
        receptor = new LzReceptor(address(lzEndpoint), _bridge);

        vm.prank(_owner());
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE, address(receptor));

        receptor.acceptBridgeRole();

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
            STARKEX_ADDRESS, abi.encodeWithSelector(IStarkEx.getOrderRoot.selector), abi.encode(STARKEX_MOCK_ORDER_ROOT)
        );

        vm.mockCall(
            STARKEX_ADDRESS,
            abi.encodeWithSelector(IStarkEx.getSequenceNumber.selector),
            abi.encode(STARKEX_MOCK_SEQUENCE_NUMBER)
        );
    }
}
