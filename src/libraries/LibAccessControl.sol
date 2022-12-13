// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IAccessControlFacet } from "src/interfaces/IAccessControlFacet.sol";

library LibAccessControl {
    bytes32 constant ACESS_CONTROL_STORAGE_POSITION = keccak256("ACESS_CONTROL_STORAGE_POSITION");

    struct AccessControlStorage {
        address owner;
        address starkExOperator;
        address interoperabilityContract;
    }

    function diamondStorage() internal pure returns (AccessControlStorage storage ds) {
        bytes32 position_ = ACESS_CONTROL_STORAGE_POSITION;
        assembly {
            ds.slot := position_
        }
    }

    function setOwner(address owner_) internal {
        AccessControlStorage storage ds = diamondStorage();
        
        address prevOwner_ = ds.owner;
        ds.owner = owner_;
        
        //emit IAccessControlFacet.OwnershipTransferred(prevOwner_, owner_);
    }

    function setStarkExOperator(address operator_) internal {
        diamondStorage().starkExOperator = operator_;
        // TODO emit IAccessControlFacet.LogSetStarkExOperator(operator_);
    }

    function setInteroperabilityContract(address interop_) internal {
        diamondStorage().interoperabilityContract = interop_;
        // TODO emit IAccessControlFacet.LogSetInteroperabilityContract(interop_);
    }

    function getOwner() internal view returns (address owner_) {
        owner_ = diamondStorage().owner;
    }

    function getStarkExOperator() internal view returns (address operator_) {
        operator_ = diamondStorage().starkExOperator;
    }

    function getInteroperabilityContract() internal view returns (address interop_) {
        interop_ = diamondStorage().interoperabilityContract;
    }
}