// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Memory.sol";

library Hash {

    /**
     * @notice Returns the keccak256 hash of the input.
     * @param src_ The input to hash.
     * @return des_ The hash of the input.
     */
    function hash(bytes memory src_) internal pure returns (bytes memory des_) {
        return Memory.toBytes(keccak256(src_));
    }
}
