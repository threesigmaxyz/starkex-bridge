// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";

library LibAccessControl {
    bytes32 constant ACCESS_CONTROL_STORAGE_POSITION = keccak256("ACCESS_CONTROL_STORAGE_POSITION");

    bytes32 constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 constant STARKEX_OPERATOR_ROLE = keccak256("STARKEX_OPERATOR_ROLE");
    bytes32 constant INTEROPERABILITY_CONTRACT_ROLE = keccak256("INTEROPERABILITY_CONTRACT_ROLE");
    bytes32 constant TOKEN_ADMIN_ROLE = keccak256("TOKEN_ADMIN_ROLE");

    struct AccessControlStorage {
        mapping(bytes32 => address) roles;
        mapping(bytes32 => address) pendingRoles;
    }

    /**
     * @notice Emits that a role was set for an account.
     * @param role The role.
     * @param previousAccount The previous account assigned to the role.
     * @param newAccount The new account assigned.
     */
    event LogRoleTransferred(bytes32 indexed role, address indexed previousAccount, address indexed newAccount);

    /**
     * @notice Emits that a pending role was set for an account.
     * @param role The role.
     * @param newAccount The new account assigned.
     */
    event LogSetPendingRole(bytes32 indexed role, address indexed newAccount);

    error UnauthorizedError();
    error NotPendingRoleError();

    /// @dev Storage of this facet using diamond storage.
    function accessControlStorage() internal pure returns (AccessControlStorage storage acs) {
        bytes32 position_ = ACCESS_CONTROL_STORAGE_POSITION;
        assembly {
            acs.slot := position_
        }
    }

    /**
     * @notice Accepts the given role.
     * @param role_ The role.
     */
    function acceptRole(bytes32 role_) internal {
        AccessControlStorage storage acs = accessControlStorage();

        if (msg.sender != acs.pendingRoles[role_]) revert NotPendingRoleError();

        address prevAccount_ = acs.roles[role_];
        acs.roles[role_] = msg.sender;

        acs.pendingRoles[role_] = address(0);

        emit LogRoleTransferred(role_, prevAccount_, msg.sender);
    }

    /**
     * @notice Sets the role to a pending account.
     * @param role_ The role.
     * @param account_ The address of the pending account.
     */
    function setPendingRole(bytes32 role_, address account_) internal {
        accessControlStorage().pendingRoles[role_] = account_;
        emit LogSetPendingRole(role_, account_);
    }

    /**
     * @notice Gets the account assigned to a role.
     * @param role_ The role.
     * @return The address.
     */
    function getRole(bytes32 role_) internal view returns (address) {
        return accessControlStorage().roles[role_];
    }

    /**
     * @notice Throws if called by any account other than the one assigned to the role.
     * @param role_ The role.
     */
    function onlyRole(bytes32 role_) internal view {
        if (msg.sender != accessControlStorage().roles[role_]) revert UnauthorizedError();
    }
}