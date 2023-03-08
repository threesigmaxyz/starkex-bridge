// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

library D {
    struct Label {
        bytes32 data;
        uint256 length;
    }

    struct Edge {
        bytes32 node;
        Label label;
    }

    struct Node {
        Edge[2] children;
    }

    struct Iter {
        bytes32[] keys;
        bytes32[] values;
        uint8[] prefixesLengths;
        bytes32[] siblings;
        uint256 currentKey;
        uint256 prefixesLengthsOffset;
        uint256 siblingsOffset;
    }
}
