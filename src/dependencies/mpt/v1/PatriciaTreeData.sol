// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/**
    MIT License
    Original author: chriseth
*/
library D {
    struct Label {
        bytes32 data;
        uint length;
    }

    struct Edge {
        bytes32 node;
        Label label;
    }

    struct Node {
        Edge[2] children;
    }
}