// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Memory } from "./Memory.sol";

library Bytes {
    uint256 internal constant BYTES_HEADER_SIZE = 32;

    /**
     *  @notice Checks if two `bytes memory` variables are equal. This is done using hashing,
     *           which is much more gas efficient then comparing each byte individually.
     *           Equality means that:
     *           - 'self.length == other.length'
     *           - For 'n' in '[0, self.length)', 'self[n] == other[n]'
     *  @param self_ The first `bytes memory` variable to compare.
     *  @param other_ The second `bytes memory` variable to compare.
     *  @return equal_ 'true' if the two `bytes memory` variables are equal, otherwise 'false'.
     */
    function equals(bytes memory self_, bytes memory other_) internal pure returns (bool equal_) {
        if (self_.length != other_.length) return false;

        uint256 addr_;
        uint256 addr2_;
        assembly {
            addr_ := add(self_, BYTES_HEADER_SIZE)
            addr2_ := add(other_, BYTES_HEADER_SIZE)
        }
        equal_ = Memory.equals(addr_, addr2_, self_.length);
    }

    /**
     * @notice Copies a section of 'self' into a new array, starting at the provided 'startIndex'.
     *         Returns the new copy.
     *         Requires that 'startIndex <= self.length'
     *         The length of the substring is: 'self.length - startIndex'
     * @param self_ The `bytes memory` variable to slice.
     * @param startIndex_ The index to start slicing from.
     * @return Bytes The substring.
     */
    function substr(bytes memory self_, uint256 startIndex_) internal pure returns (bytes memory) {
        require(startIndex_ <= self_.length);
        uint256 len_ = self_.length - startIndex_;
        uint256 addr_ = Memory.dataPtr(self_);
        return Memory.toBytes(addr_ + startIndex_, len_);
    }

    /**
     * @notice Copies 'len' bytes from 'self' into a new array, starting at the provided 'startIndex'.
     *         Returns the new copy.
     *         Requires that:
     *         - 'startIndex + len <= self.length'
     *         The length of the substring is: 'len'
     * @param self_ The `bytes memory` variable to slice.
     * @param startIndex_ The index to start slicing from.
     * @param len_ The length of the substring.
     * @return Bytes The substring.
     */
    function substr(bytes memory self_, uint256 startIndex_, uint256 len_) internal pure returns (bytes memory) {
        require(startIndex_ + len_ <= self_.length);
        if (len_ == 0) return "";

        uint256 addr_ = Memory.dataPtr(self_);
        return Memory.toBytes(addr_ + startIndex_, len_);
    }
}
