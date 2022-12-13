// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { LibDiamond }       from "src/libraries/LibDiamond.sol";
import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";

/// @title Modifiers contract.
abstract contract Modifiers {

    //==============================================================================//
    //=== Errors                                                                 ===//
    //==============================================================================//

    error NotOwnerError();
    error NotStarkExOperatorError();
    error NotInteroperabilityContractError();
    error AssetNotRegisteredError(address asset);

    //==============================================================================//
    //=== Modifiers                                                              ===//
    //==============================================================================//

    /// @notice Throws if called by any account other than the owner.
    modifier onlyOwner() {
        if (msg.sender != LibDiamond.diamondStorage().contractOwner) {
            revert NotOwnerError();
        }
        _;
    }

    /// @notice Throws if called by any account other than the StarkEx operator.
    modifier onlyStarkExOperator() {
        if (msg.sender != LibAccessControl.getStarkExOperator()) {
            revert NotStarkExOperatorError();
        }
        _;
    }

    /// @notice Throws if called by any account other than the interoperablity contract.
    modifier onlyInteroperabilityContract {
        if (msg.sender != LibAccessControl.getInteroperabilityContract()) {
            revert NotInteroperabilityContractError();
        }
        _;
    }

    /// @notice Throws if the asset is not registered in the contract.
    /// @param asset_ The asset to validate.
    modifier onlyRegisteredAsset(address asset_) {
        if (!LibTokenRegister.isTokenRegistered(asset_)) {
            // TODO revert AssetNotRegisteredError(asset_);
        }
        _;
    }
}