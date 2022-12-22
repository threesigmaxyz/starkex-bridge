// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Interface for contract ownership management.
/// @dev Follows the ERC-173 Contract Ownership Standard.
interface IAccessControlFacet {

    /** 
     * @notice Sets the msg.sender address to a role.
     * @param role_ The role.
    */
    function acceptRole(bytes32 role_) external;

    /** 
     * @notice Sets a pending address to a role.
     * @param role_ The role.
     * @param account_ The address of the pending account.
    */
    function setPendingRole(bytes32 role_, address account_) external;

    /** 
     * @notice Gets the account assigned to a role.
     * @param role_ The role.
     * @return The address.
    */
    function getRole(bytes32 role_) external view returns (address);
}