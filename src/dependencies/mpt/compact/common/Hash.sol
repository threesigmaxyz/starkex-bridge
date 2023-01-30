// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Memory.sol";

library Hash {

    function hash(bytes memory src) internal pure returns (bytes memory des) {
        return Memory.toBytes(keccak256(src));
    }
}
