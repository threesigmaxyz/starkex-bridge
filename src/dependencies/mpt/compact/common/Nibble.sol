// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Nibble {
    /**
     * @notice Turns bytes into nibbles. Does not rearrange the nibbles; assumes they are already ordered in LE.
     *         Each byte is split into two nibbles, (src[i]/16 and src[i]%16) and the nibbles are concatenated.
     * @param src_ The input bytes.
     * @return des_ The nibbles.
     */
    function keyToNibbles(bytes memory src_) internal pure returns (bytes memory des_) {
        if (src_.length == 0) return des_;
        if (src_.length == 1 && uint8(src_[0]) == 0) return hex"0000";

        uint256 l_ = src_.length * 2;
        des_ = new bytes(l_);
        for (uint256 i = 0; i < src_.length; i++) {
            des_[2 * i] = bytes1(uint8(src_[i]) / 16);
            des_[2 * i + 1] = bytes1(uint8(src_[i]) % 16);
        }
    }

    /**
     * @notice nibblesToKeyLE turns a slice of nibbles w/ length k into a little endian byte array
     *         assumes nibbles are already LE, does not rearrange nibbles
     *         if the length of the input is odd, the result is [ 0000 in[0] | in[1] in[2] | ... | in[k-2] in[k-1] ]
     *         otherwise, res = [ in[0] in[1] | ... | in[k-2] in[k-1] ]
     * @param src_ The input nibbles.
     * @return des_ The bytes.
     */
    function nibblesToKeyLE(bytes memory src_) internal pure returns (bytes memory des_) {
        uint256 l_ = src_.length;
        if (l_ % 2 == 0) {
            des_ = new bytes(l_ / 2);
            for (uint256 i = 0; i < l_; i += 2) {
                uint8 a = uint8(src_[i]);
                uint8 b = uint8(src_[i + 1]);
                des_[i / 2] = bytes1(((a << 4) & 0xF0) | (b & 0x0F));
            }
        } else {
            des_ = new bytes(l_ / 2 + 1);
            des_[0] = src_[0];
            for (uint256 i = 2; i < l_; i += 2) {
                uint8 a = uint8(src_[i - 1]);
                uint8 b = uint8(src_[i]);
                des_[i / 2] = bytes1(((a << 4) & 0xF0) | (b & 0x0F));
            }
        }
    }
}
