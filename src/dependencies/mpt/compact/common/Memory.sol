// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Memory {

    uint internal constant WORD_SIZE = 32;
	uint256 internal constant BYTES_HEADER_SIZE = 32;

	/** 
	 * @notice Compares the 'len' bytes starting at address 'addr' in memory with the 'len'
     *         bytes starting at 'addr2'.
	 * @param addr_ The address of the first bytes to compare.
	 * @param addr2_ The address of the second bytes to compare.
	 * @param len_ The number of bytes to compare.
	 * @return equal_ 'true' if the bytes are the same, otherwise 'false'.
	 */
    function equals(uint addr_, uint addr2_, uint len_) internal pure returns (bool equal_) {
        assembly {
            equal_ := eq(keccak256(addr_, len_), keccak256(addr2_, len_))
        }
    }

	/** 
     * @notice Compares the 'len' bytes starting at address 'addr' in memory with the bytes stored in
     *         'bts'. It is allowed to set 'len' to a lower value then 'bts.length', in which case only
     *         the first 'len' bytes will be compared.
     *         Requires that 'bts.length >= len'
	 * @param addr_ The address of the first bytes to compare.
	 * @param bts_ The bytes to compare.
	 * @param len_ The number of bytes to compare.
	 * @return equal_ 'true' if the bytes are the same, otherwise 'false'.
	 */
    function equals(uint addr_, uint len_, bytes memory bts_) internal pure returns (bool equal_) {
        require(bts_.length >= len_);
        uint addr2_;
        assembly {
            addr2_ := add(bts_, BYTES_HEADER_SIZE)
        }
        return equals(addr_, addr2_, len_);
    }

	/** 
	 * @notice Returns a memory pointer to the data portion of the provided bytes array.
	 * @param bts_ The bytes array to get the data pointer for.
	 * @return addr_ The memory pointer to the data portion of the provided bytes array.
	 */
	function dataPtr(bytes memory bts_) internal pure returns (uint addr_) {
		assembly {
			addr_ := add(bts_, BYTES_HEADER_SIZE)
		}
	}

	/** 
	 * @notice Creates a 'bytes memory' variable from the memory address 'addr', with the
	 *         length 'len'. The function will allocate new memory for the bytes array, and
	 *         the 'len bytes starting at 'addr' will be copied into that new memory.
	 * @param addr_ The memory address to copy the bytes from. 
	 * @param len_ The number of bytes to copy.
	 * @return bts_ The newly created 'bytes memory' variable.
	 */
	function toBytes(uint addr_, uint len_) internal pure returns (bytes memory bts_) {
		bts_ = new bytes(len_);
		uint btsptr_;
		assembly {
			btsptr_ := add(bts_, BYTES_HEADER_SIZE)
		}
		copy(addr_, btsptr_, len_);
	}
	
	/** 
	 * @notice Copies 'self' into a new 'bytes memory'.
	 *         Returns the newly created 'bytes memory'
	 *         The returned bytes will be of length '32'.
	 * @param self_ The bytes32 to copy.
	 * @return bts_ The newly created 'bytes memory' variable.
	 */
	function toBytes(bytes32 self_) internal pure returns (bytes memory bts_) {
		bts_ = new bytes(32);
		assembly {
			mstore(add(bts_, BYTES_HEADER_SIZE), self_)
		}
	}

	/** 
	 * @notice Copy 'len' bytes from memory address 'src', to address 'dest'.
	 *         This function does not check the address or destination, it only copies the bytes.
	 * @param src_ The memory address to copy the bytes from.
	 * @param dest_ The memory address to copy the bytes to.
	 * @param len_ The number of bytes to copy.
	 */
	function copy(uint src_, uint dest_, uint len_) internal pure {
		// Copy word-length chunks while possible
		for (; len_ >= WORD_SIZE; len_ -= WORD_SIZE) {
			assembly {
				mstore(dest_, mload(src_))
			}
			dest_ += WORD_SIZE;
			src_ += WORD_SIZE;
		}

		// If len == 0, there are no remaining bytes left to copy.
		if (len_ == 0) return;

		// Copy remaining bytes
		uint mask_ = 256 ** (WORD_SIZE - len_) - 1;
		assembly {
			let srcpart_ := and(mload(src_), not(mask_))
			let destpart_ := and(mload(dest_), mask_)
			mstore(dest_, or(destpart_, srcpart_))
		}
	}

	/**  
	 * @notice This function does the same as 'dataPtr(bytes memory)', but will also return the
	 *         length of the provided bytes array.
	 * @param bts_ The bytes array to get the data pointer and length for.
	 * @return addr_ The memory pointer to the data portion of the provided bytes array.
	 * @return len_ The length of the provided bytes array.
	 */
	function fromBytes(bytes memory bts_) internal pure returns (uint addr_, uint len_) {
		len_ = bts_.length;
		assembly {
			addr_ := add(bts_, BYTES_HEADER_SIZE)
		}
	}
}
