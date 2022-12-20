// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";

library LibState {
    bytes32 constant STATE_STORAGE_POSITION = keccak256("STATE_STORAGE_POSITION");

    struct StateStorage {
        uint256 orderRoot;
        mapping(address => uint) lzRemoteMessageCounter;
    }

    function stateStorage() internal pure returns (StateStorage storage ds) {
        bytes32 position_ = STATE_STORAGE_POSITION;
        assembly {
            ds.slot := position_
        }
    }

    function getOrderRoot() internal view returns (uint256) {
        return stateStorage().orderRoot;
    }
}