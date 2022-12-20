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
    }

    event RoleTransferred(bytes32 indexed role, address indexed previousAccount, address indexed newAccount);

    error NotRoleError();

    function accessControlStorage() internal pure returns (AccessControlStorage storage acs) {
        bytes32 position_ = ACCESS_CONTROL_STORAGE_POSITION;
        assembly {
            acs.slot := position_
        }
    }

    function setRole(bytes32 role_, address account_) internal {
        AccessControlStorage storage acs = accessControlStorage();
        
        address prevAccount_ = acs.roles[role_];
        acs.roles[role_] = account_;

        emit RoleTransferred(role_, prevAccount_, account_);
    }

    /// @notice Throws if called by any account other than the role.
    function onlyRole(bytes32 role_) internal view {
        if (msg.sender != accessControlStorage().roles[role_]) revert NotRoleError();
    }
}