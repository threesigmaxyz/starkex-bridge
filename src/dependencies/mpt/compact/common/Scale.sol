// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Input.sol";

library Scale {
    using Input for Input.Data;

    /**
     * @notice Accepts a byte array representing a SCALE encoded byte array and performs SCALE decoding
     *         of the byte array.
     * @param data_ The byte array to decode.
     * @return decodedBytesArray_ The decoded byte array.
     */
    function decodeByteArray(Input.Data memory data_) internal pure returns (bytes memory decodedBytesArray_) {
        uint32 len = decodeU32(data_);
        if (len == 0) return decodedBytesArray_;
        decodedBytesArray_ = data_.decodeBytesN(len);
    }

    /**
     * @notice Accepts a byte array representing a SCALE encoded integer and performs SCALE decoding of the int.
     * @param data_ The byte array to decode.
     * @return decodedInt_ The decoded integer.
     */
    function decodeU32(Input.Data memory data_) internal pure returns (uint32) {
        uint8 b0_ = data_.decodeU8();
        uint8 mode_ = b0_ & 3;
        require(mode_ <= 2, "scale decode not support");
        if (mode_ == 0) return uint32(b0_) >> 2;
        uint8 b1_ = data_.decodeU8();
        if (mode_ == 1) {
            uint16 decodedU32Mode1_ = uint16(b0_) | (uint16(b1_) << 8);
            return uint32(decodedU32Mode1_) >> 2;
        }
        uint8 b2_ = data_.decodeU8();
        uint8 b3_ = data_.decodeU8();
        uint32 decodedU32Mode2_ = uint32(b0_) | (uint32(b1_) << 8) | (uint32(b2_) << 18) | (uint32(b3_) << 24);
        return decodedU32Mode2_ >> 2;
    }

    /**
     * @notice Performs the following: b -> [encodeInteger(len(b)) b]
     * @param src_ The byte array to encode.
     * @return des_ The encoded byte array.
     */
    function encodeByteArray(bytes memory src_) internal pure returns (bytes memory des_, uint256 bytesEncoded_) {
        uint256 n;
        (des_, n) = encodeU32(uint32(src_.length));
        bytesEncoded_ = n + src_.length;
        des_ = abi.encodePacked(des_, src_);
    }

    /**
     * @notice encodeU32 performs the following on integer i:
     *         i  -> i^0...i^n where n is the length in bits of i
     *         note that the bit representation of i is in little endian; ie i^0 is the least significant bit of i,
     *         and i^n is the most significant bit
     *         if n < 2^6 write [00 i^2...i^8 ] [ 8 bits = 1 byte encoded  ]
     *         if 2^6 <= n < 2^14 write [01 i^2...i^16] [ 16 bits = 2 byte encoded  ]
     *         if 2^14 <= n < 2^30 write [10 i^2...i^32] [ 32 bits = 4 byte encoded  ]
     *         if n >= 2^30 write [lower 2 bits of first byte = 11] [upper 6 bits of first byte = # of bytes following less 4]
     *         [append i as a byte array to the first byte]
     * @param i_ The integer to encode.
     * @return des_ The encoded integer.
     */
    function encodeU32(uint32 i_) internal pure returns (bytes memory, uint256) {
        // 1<<6
        if (i_ < 64) {
            uint8 v_ = uint8(i_) << 2;
            bytes1 b_ = bytes1(v_);
            bytes memory des_ = new bytes(1);
            des_[0] = b_;
            return (des_, 1);
            // 1<<14
        } else if (i_ < 16_384) {
            uint16 v_ = uint16(i_ << 2) + 1;
            bytes memory des_ = new bytes(2);
            des_[0] = bytes1(uint8(v_));
            des_[1] = bytes1(uint8(v_ >> 8));
            return (des_, 2);
            // 1<<30
        } else if (i_ < 1_073_741_824) {
            uint32 v_ = uint32(i_ << 2) + 2;
            bytes memory des_ = new bytes(4);
            des_[0] = bytes1(uint8(v_));
            des_[1] = bytes1(uint8(v_ >> 8));
            des_[2] = bytes1(uint8(v_ >> 16));
            des_[3] = bytes1(uint8(v_ >> 24));
            return (des_, 4);
        } else {
            revert("scale encode not support");
        }
    }
}
