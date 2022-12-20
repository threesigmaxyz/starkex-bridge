// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAccessControl} from "src/libraries/LibAccessControl.sol";
import {OnlyOwner} from "src/modifiers/OnlyOwner.sol";
import {IAccessControlFacet} from "src/interfaces/IAccessControlFacet.sol";

/// @title Facet for access control operations.
/// @dev Follows the ERC-173 contract ownership standard.
contract AccessControlFacet is OnlyOwner, IAccessControlFacet {
    // TODO supportsInterface for ERC-173 0x7f5828d0

    /// @inheritdoc IAccessControlFacet
    /// @dev Only callable by the owner role.
    function setRole(
        bytes32 role_,
        address account_
    ) external override onlyOwner {
        LibAccessControl.setRole(role_, account_);
    }

    function getRole(bytes32 role_) external view override returns (address) {
        return LibAccessControl.accessControlStorage().roles[role_];
    }
}