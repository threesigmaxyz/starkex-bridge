// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Modifiers }     from "src/Modifiers.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

import { IAccessControlFacet } from "src/interfaces/IAccessControlFacet.sol";

/// @title Facet for access control operations.
/// @dev Follows the ERC-173 contract ownership standard.
contract AccessControlFacet is Modifiers, IAccessControlFacet {

    // TODO init with starkExOperator
    // TODO supportsInterface for ERC-173 0x7f5828d0

    //==============================================================================//
    //=== Setters                                                                ===//
    //==============================================================================//

    /// @inheritdoc IAccessControlFacet
    /// @dev Only callable by the owner.
    function transferOwnership(address owner_) external override onlyOwner {
        // TODO move to LibAccessControl
        LibAccessControl.setOwner(owner_);
    }

    /// @inheritdoc IAccessControlFacet
    /// @dev Only callable by the owner.
    function setStarkExOperator(address operator_) external override onlyOwner {        
        // TODO move event emission to LibAccessControl
        LibAccessControl.diamondStorage().starkExOperator = operator_;
        emit LogSetStarkExOperator(operator_);
    }

    /// @inheritdoc IAccessControlFacet
    /// @dev Only callable by the owner.
    function setInteroperabilityContract(address interop_) external override onlyOwner {        
        // TODO move event emission to LibAccessControl
        LibAccessControl.diamondStorage().interoperabilityContract = interop_;
        emit LogSetInteroperabilityContract(interop_);
    }

    //==============================================================================//
    //=== Getters                                                                ===//
    //==============================================================================//

    /// @inheritdoc IAccessControlFacet
    function owner() external view override returns (address owner_) {
        owner_ = LibAccessControl.getOwner();
    }

    /// @inheritdoc IAccessControlFacet
    function getStarkExOperator() external override returns (address operator_) {
        operator_ = LibAccessControl.getStarkExOperator();
    }

    /// @inheritdoc IAccessControlFacet
    function getInteroperabilityContract() external override returns (address interop_) {
        interop_ = LibAccessControl.getInteroperabilityContract();
    }
}