// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Bytes.sol";

library Input {
    using Bytes for bytes;

    struct Data {
        uint256 offset;
        bytes raw;
    }

    /**
     * @notice from creates a new Data struct from the input bytes with 0 offset.
     * @param data_ The input bytes.
     * @return Data struct.
     */
    function from(bytes memory data_) internal pure returns (Data memory) {
        return Data({ offset: 0, raw: data_ });
    }

    /**
     * @notice Shifts the offset of the Data struct by the given size.
     * @param data_ The Data struct.
     * @param size_ The size to shift by.
     */
    modifier shift(Data memory data_, uint256 size_) {
        require(data_.raw.length >= data_.offset + size_, "Input: Out of range");
        _;
        data_.offset += size_;
    }

    /**
     * @notice decodeU8 decodes a uint8 from the Data struct and shifts the offset by 1.
     * @param data_ The Data struct.
     * @return value_ The decoded uint8.
     */
    function decodeU8(Data memory data_) internal pure shift(data_, 1) returns (uint8 value_) {
        value_ = uint8(data_.raw[data_.offset]);
    }

    /**
     * @notice Decodes a uint16 from the Data struct and shifts the offset by 2.
     * @param data_ The Data struct.
     * @return value_ The decoded uint16.
     */
    function decodeU16(Data memory data_) internal pure returns (uint16 value_) {
        value_ = uint16(decodeU8(data_));
        value_ |= (uint16(decodeU8(data_)) << 8);
    }

    /**
     * @notice Decodes a uint32 from the Data struct and shifts the offset by 4.
     * @param data_ The Data struct.
     * @return value_ The decoded uint32.
     */
    function decodeU32(Data memory data_) internal pure returns (uint32 value_) {
        value_ = uint32(decodeU16(data_));
        value_ |= (uint32(decodeU16(data_)) << 16);
    }

    /**
     * @notice Decodes N bytes from the Data struct and shifts the offset by N.
     * @param data_ The Data struct.
     * @param N_ The number of bytes to decode.
     * @return value_ The decoded bytes.
     */
    function decodeBytesN(Data memory data_, uint256 N_) internal pure shift(data_, N_) returns (bytes memory value_) {
        value_ = data_.raw.substr(data_.offset, N_);
    }
}
