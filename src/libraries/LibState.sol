// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";

library LibState {
    bytes32 constant STATE_STORAGE_POSITION = keccak256("STATE_STORAGE_POSITION");

    struct StateStorage {
        uint256 orderRoot;
    }

    /// @dev Storage of this facet using diamond storage.
    function stateStorage() internal pure returns (StateStorage storage ds) {
        bytes32 position_ = STATE_STORAGE_POSITION;
        assembly {
            ds.slot := position_
        }
    }

    /**
     * @notice Get the order root from storage.
     * @return The order root.
     */
    function getOrderRoot() internal view returns (uint256) {
        return stateStorage().orderRoot;
    }
}