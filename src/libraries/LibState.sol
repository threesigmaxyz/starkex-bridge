// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";

library LibState {
    bytes32 constant STATE_STORAGE_POSITION = keccak256("STATE_STORAGE_POSITION");

    struct StateStorage {
        uint256 orderRoot;
    }

    /**
     * @notice Emits a new order root change.
     * @param orderRoot The order root.
     */
    event LogSetOrderRoot(uint256 indexed orderRoot);

    /// @dev Storage of this facet using diamond storage.
    function stateStorage() internal pure returns (StateStorage storage ds) {
        bytes32 position_ = STATE_STORAGE_POSITION;
        assembly {
            ds.slot := position_
        }
    }

    /**
     * @notice Sets the order root.
     * @param orderRoot_ The order root.
     */
    function setOrderRoot(uint256 orderRoot_) internal {
        stateStorage().orderRoot = orderRoot_;
        emit LogSetOrderRoot(orderRoot_);
    }

    /**
     * @notice Get the order root from storage.
     * @return The order root.
     */
    function getOrderRoot() internal view returns (uint256) {
        return stateStorage().orderRoot;
    }
}