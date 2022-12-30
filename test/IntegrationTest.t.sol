// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";

import { LzFixture } from "test/fixtures/LzFixture.sol";
import { LzEndpointMock } from "test/mocks/lz/LzEndpointMock.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { LzReceptor } from "src/interoperability/LzReceptor.sol";
import { LzTransmitter } from "src/interoperability/LzTransmitter.sol";

contract LzTransmitterTest is LzFixture {
    //==============================================================================//
    //=== Tests                                                                  ===//
    //==============================================================================//

    function test_keep_ok() public {
        // Arrange
        address keeper_ = vm.addr(42);
        vm.deal(keeper_, 100 ether);

        // Act
        vm.prank(keeper_);
        _transmitter.keep{value: 1 ether}(MOCK_CHAIN_ID, payable(keeper_));

        vm.prank(_owner());
        _receptor.setOrderRoot();

        assertEq(IStateFacet(_bridge).getOrderRoot(), STARKEX_MOCK_ORDER_ROOT);
    }
}
