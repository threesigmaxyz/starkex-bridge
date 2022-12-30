//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

contract AccessControlFacetTest is BaseFixture {
    //==============================================================================//
    //=== Events                                                                 ===//
    //==============================================================================//

    event LogRoleTransferred(bytes32 indexed role, address indexed previousAccount, address indexed newAccount);
    event LogSetPendingRole(bytes32 indexed role, address indexed newAccount);

    function test_transferRole_ok(bytes32 role1_, bytes32 role2_) public {
        // Arrange
        address account1_ = vm.addr(1);
        address account2_ = vm.addr(2);
        vm.label(account1_, "account1");
        vm.label(account2_, "account2");

        // Act + Assert
        _transferRole_and_validate(role1_, account1_);
        _transferRole_and_validate(role2_, account2_);
        _transferRole_and_validate(role1_, address(0));
        _transferRole_and_validate(role2_, address(0));
        _transferRole_and_validate(role1_, account1_);
        _transferRole_and_validate(role2_, account2_);
    }

    function test_setPendingRole_UnauthorizedError(bytes32 role_) public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.UnauthorizedError.selector));

        // Act + Assert
        vm.prank(_intruder());
        IAccessControlFacet(_bridge).setPendingRole(role_, _recipient());
    }

    function test_acceptRole_NotPendingRoleError(bytes32 role_) public {
        // Arrange
        address legitAccount_ = vm.addr(1);
        vm.label(legitAccount_, "legitAccount");
        // And
        _call_setPendingRole_and_validate(role_, legitAccount_);
        // And
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.NotPendingRoleError.selector));

        // Act + Assert
        vm.prank(_intruder());
        IAccessControlFacet(_bridge).acceptRole(role_);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _call_setPendingRole_and_validate(bytes32 role_, address account_) internal {
        // Arrange
        vm.expectEmit(true, true, false, true, _bridge);
        emit LogSetPendingRole(role_, account_);

        // Act + Assert
        vm.prank(_owner());
        IAccessControlFacet(_bridge).setPendingRole(role_, account_);
    }

    function _transferRole_and_validate(bytes32 role_, address account_) internal {
        // Arrange
        _call_setPendingRole_and_validate(role_, account_);
        // And
        vm.expectEmit(true, true, true, true, _bridge);
        address previousAccount_ = IAccessControlFacet(_bridge).getRole(role_);
        emit LogRoleTransferred(role_, previousAccount_, account_);

        // Act + Assert
        vm.prank(account_);
        IAccessControlFacet(_bridge).acceptRole(role_);

        // Assert
        assertEq(IAccessControlFacet(_bridge).getRole(role_), account_);
    }
}
