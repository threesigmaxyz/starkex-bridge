//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

contract StateFacetTest is BaseFixture {
    //==============================================================================//
    //=== Events                                                                 ===//
    //==============================================================================//

    event LogSetOrderRoot(uint256 indexed orderRoot);

    //==============================================================================//
    //=== setOrderRoot Tests                                                     ===//
    //==============================================================================//

    function test_setOrderRoot_ok(uint256 orderRoot1, uint256 orderRoot2) public {
        // Act + Assert
        assertEq(IStateFacet(_bridge).getOrderRoot(), 0);
        _setOrderRoot(orderRoot1);
        _setOrderRoot(orderRoot2);
    }

    function test_setOrderRoot_UnauthorizedError() public {
        // Act + Assert
        vm.prank(_intruder());
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.UnauthorizedError.selector));
        IStateFacet(_bridge).setOrderRoot(0);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _setOrderRoot(uint256 orderRoot) internal {
        // Arrange
        vm.expectEmit(true, false, false, true, _bridge);
        emit LogSetOrderRoot(orderRoot);

        // Act + Assert
        vm.prank(_mockInteropContract());
        IStateFacet(_bridge).setOrderRoot(orderRoot);

        // Assert
        assertEq(IStateFacet(_bridge).getOrderRoot(), orderRoot);
    }
}
