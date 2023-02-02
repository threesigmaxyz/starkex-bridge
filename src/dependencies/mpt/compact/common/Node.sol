// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Input.sol";
import "./Nibble.sol";
import "./Bytes.sol";
import "./Hash.sol";
import "./Scale.sol";

library Node {
    using Input for Input.Data;
    using Bytes for bytes;

    // Node kinds, no extension
    uint8 internal constant LEAF = 1;
    uint8 internal constant BRANCH_WITHVALUE = 3;

    struct NodeHandle {
        bytes data;
        bool exist;
        bool isInline;
    }

    struct Branch {
        bytes key; //partialkey
        NodeHandle[16] children;
        bytes value;
    }

    struct Leaf {
        bytes key; //partialkey
        bytes value;
    }

    /**
     * @notice Decodes a byte array into a branch node.
     * @param data_ The input data.
     * @param header_ The header byte.
     * @return branch_ The decoded branch node.
     */
    function decodeBranch(Input.Data memory data_, uint8 header_) internal pure returns (Branch memory branch_) {
        branch_.key = decodeNodeKey(data_, header_);
        uint8[2] memory bitmap_;
        bitmap_[0] = data_.decodeU8();
        bitmap_[1] = data_.decodeU8();
        uint8 nodeType = header_ >> 6;
        if (nodeType == BRANCH_WITHVALUE) branch_.value = Scale.decodeByteArray(data_);

        for (uint8 i = 0; i < 16; i++) {
            if (((bitmap_[i / 8] >> (i % 8)) & 1) == 1) {
                bytes memory childData_ = Scale.decodeByteArray(data_);
                bool isInline_ = true;
                if (childData_.length == 32) isInline_ = false;

                branch_.children[i] = NodeHandle({data: childData_, isInline: isInline_, exist: true});
            }
        }
    }

    /**
     * @notice decodeLeaf decodes a byte array into a leaf node.
     * @param data_ The input data.
     * @param header_ The header byte.
     * @return leaf_ The decoded leaf node.
     */
    function decodeLeaf(Input.Data memory data_, uint8 header_) internal pure returns (Leaf memory leaf_) {
        leaf_.key = decodeNodeKey(data_, header_);
        leaf_.value = Scale.decodeByteArray(data_);
    }

    /**
     * @notice Decodes the key of a node.
     * @param data_ The input data.
     * @param header_ The header byte.
     * @return key_ The decoded key.
     */
    function decodeNodeKey(Input.Data memory data_, uint8 header_) internal pure returns (bytes memory key_) {
        uint256 keyLen_ = header_ & 0x3F;
        if (keyLen_ == 0x3f) {
            while (keyLen_ < 65_536) {
                uint8 nextKeyLen_ = data_.decodeU8();
                keyLen_ += uint256(nextKeyLen_);
                if (nextKeyLen_ < 0xFF) break;
                require(keyLen_ < 65_536, "Size limit reached for a nibble slice");
            }
        }
        if (keyLen_ != 0) {
            key_ = data_.decodeBytesN(keyLen_ / 2 + (keyLen_ % 2));
            key_ = Nibble.keyToNibbles(key_);
            if (keyLen_ % 2 == 1) {
                key_ = key_.substr(1);
            }
        }
    }

    /**
     * @notice encodeBranch encodes a branch.
     * @param branch_ The branch to encode.
     * @return encoding_ The encoded branch.
     */
    function encodeBranch(Branch memory branch_) internal pure returns (bytes memory encoding_) {
        encoding_ = encodeBranchHeader(branch_);
        encoding_ = abi.encodePacked(encoding_, Nibble.nibblesToKeyLE(branch_.key));
        encoding_ = abi.encodePacked(encoding_, u16ToBytes(childrenBitmap(branch_)));
        if (branch_.value.length != 0) {
            bytes memory encValue;
            (encValue,) = Scale.encodeByteArray(branch_.value);
            encoding_ = abi.encodePacked(encoding_, encValue);
        }

        bytes memory childData_;
        bytes memory encChild_;
        bytes memory hash_;
        for (uint8 i = 0; i < 16; i++) {
            if (branch_.children[i].exist) {
                childData_ = branch_.children[i].data;
                require(childData_.length > 0, "miss child data");
                childData_.length <= 32 ? hash_ = childData_ : hash_ = Hash.hash(childData_);
                (encChild_,) = Scale.encodeByteArray(hash_);
                encoding_ = abi.encodePacked(encoding_, encChild_);
            }
        }
    }

    /**
     * @notice Encodes a leaf.
     * @param leaf_ The leaf to encode.
     * @return encoding_ The encoded leaf.
     */
    function encodeLeaf(Leaf memory leaf_) internal pure returns (bytes memory encoding_) {
        encoding_ = encodeLeafHeader(leaf_);
        encoding_ = abi.encodePacked(encoding_, Nibble.nibblesToKeyLE(leaf_.key));
        (bytes memory encValue,) = Scale.encodeByteArray(leaf_.value);
        encoding_ = abi.encodePacked(encoding_, encValue);
    }

    /**
     * @notice Encodes a branch header.
     * @param branch_ The branch to encode.
     * @return branchHeader_ The encoded branch header.
     */
    function encodeBranchHeader(Branch memory branch_) internal pure returns (bytes memory branchHeader_) {
        uint8 header_;
        uint256 valueLen_ = branch_.value.length;
        require(valueLen_ < 65_536, "partial key too long");
        valueLen_ == 0 ? header_ = 2 << 6 : header_ = 3 << 6; // 2 for branch without value, 3 for branch with value

        bytes memory encPkLen_;
        uint256 pkLen_ = branch_.key.length;
        if (pkLen_ >= 63) {
            header_ = header_ | 0x3F;
            encPkLen_ = encodeExtraPartialKeyLength(uint16(pkLen_));
        } else {
            header_ = header_ | uint8(pkLen_);
        }
        branchHeader_ = abi.encodePacked(header_, encPkLen_);
    }

    /**
     * @notice Encodes a leaf header.
     * @param leaf_ The leaf to encode.
     * @return leafHeader_ The encoded leaf header.
     */
    function encodeLeafHeader(Leaf memory leaf_) internal pure returns (bytes memory leafHeader_) {
        uint8 header_ = 1 << 6;
        uint256 pkLen_ = leaf_.key.length;
        bytes memory encPkLen_;
        if (pkLen_ >= 63) {
            header_ = header_ | 0x3F;
            encPkLen_ = encodeExtraPartialKeyLength(uint16(pkLen_));
        } else {
            header_ = header_ | uint8(pkLen_);
        }
        leafHeader_ = abi.encodePacked(header_, encPkLen_);
    }

    /**
     * @notice Encodes the extra partial key length.
     * @param pkLen_ The partial key length.
     * @return encPkLen_ The encoded partial key length.
     */
    function encodeExtraPartialKeyLength(uint16 pkLen_) internal pure returns (bytes memory encPkLen_) {
        pkLen_ -= 63;
        for (uint8 i = 0; i < 65_536; i++) {
            if (pkLen_ < 255) {
                encPkLen_ = abi.encodePacked(encPkLen_, uint8(pkLen_));
                break;
            } else {
                encPkLen_ = abi.encodePacked(encPkLen_, uint8(255));
            }
        }
    }

    /**
     * @notice Converts a uint16 into a 2-byte slice.
     * @param src_ The uint16 to convert.
     * @return des_ The converted slice.
     */
    function u16ToBytes(uint16 src_) internal pure returns (bytes memory des_) {
        des_ = new bytes(2);
        des_[0] = bytes1(uint8(src_ & 0x00FF));
        des_[1] = bytes1(uint8((src_ >> 8) & 0x00FF));
    }

    /**
     * @notice Gets the children bitmap from a branch.
     * @param branch_ The branch to get the children bitmap from.
     * @return bitmap_ The children bitmap.
     */
    function childrenBitmap(Branch memory branch_) internal pure returns (uint16 bitmap_) {
        for (uint256 i = 0; i < 16; i++) {
            if (branch_.children[i].exist) {
                bitmap_ = bitmap_ | uint16(1 << i);
            }
        }
    }
}
