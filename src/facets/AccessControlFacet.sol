// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { OnlyOwner } from "src/modifiers/OnlyOwner.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";

/// @title Facet for access control operations.
contract AccessControlFacet is OnlyOwner, IAccessControlFacet {
    /// @inheritdoc IAccessControlFacet
    function acceptRole(bytes32 role_) external override {
        LibAccessControl.acceptRole(role_);
    }

    /// @inheritdoc IAccessControlFacet
    /// @dev Only callable by the owner role.
    function setPendingRole(bytes32 role_, address account_) external override onlyOwner {
        LibAccessControl.setPendingRole(role_, account_);
    }

    /// @inheritdoc IAccessControlFacet
    function getRole(bytes32 role_) external view override returns (address) {
        return LibAccessControl.getRole(role_);
    }
}