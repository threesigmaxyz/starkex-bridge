// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Interface for contract ownership management.
/// @dev Follows the ERC-173 Contract Ownership Standard.
interface IAccessControlFacet {
    
    /// @notice Sets an address to a role.
    /// @param role_  The role.
    /// @param account_ The address of the account.
    function setRole(bytes32 role_, address account_) external;

    /// @notice Gets the account assigned to a role.
    function getRole(bytes32 role_) external view returns (address);
}