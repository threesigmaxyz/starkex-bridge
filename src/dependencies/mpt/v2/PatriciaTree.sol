// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import { Test } from "@forge-std/Test.sol";
import { stdJson } from "@forge-std/StdJson.sol";

import { D } from "./Data.sol";
import { Utils } from "./Utils.sol";
import { QuickSort } from "./QuickSort.sol";

contract PatriciaTree is Test {
    using stdJson for string;

    // Mapping of hash of key to value
    mapping(bytes32 => bytes) keysToValues;
    // Particia tree nodes (hash to decoded contents)
    mapping(bytes32 => D.Node) nodes;
    // The current root hash, keccak256(node(path_M('')), path_M(''))
    bytes32 public root;
    D.Edge rootEdge;

    // TODO also return the proof
    function insert(bytes memory key, bytes memory value) public {
        D.Label memory k = D.Label(keccak256(key), 256);
        bytes32 valueHash = keccak256(value);
        keysToValues[k.data] = value;
        // keys.push(key);
        D.Edge memory e;
        if (rootEdge.node == 0 && rootEdge.label.length == 0) {
            // Empty Trie
            e.label = k;
            e.node = valueHash;
        } else {
            e = insertAtEdge(rootEdge, k, valueHash);
        }

        root = edgeHash(e);
        rootEdge = e;
    }

    function getNode(bytes32 nodeHash) public view returns (uint256, bytes32, bytes32, uint256, bytes32, bytes32) {
        D.Node memory n = nodes[nodeHash];
        return (
            n.children[0].label.length,
            n.children[0].label.data,
            n.children[0].node,
            n.children[1].label.length,
            n.children[1].label.data,
            n.children[1].node
        );
    }

    function getRootEdge() public view returns (uint256, bytes32, bytes32) {
        return (rootEdge.label.length, rootEdge.label.data, rootEdge.node);
    }

    // Returns the Merkle-proof for the given key
    // Proof format should be:
    //  - uint branchMask - bitmask with high bits at the positions in the key
    //                    where we have branch nodes (bit in key denotes direction)
    //  - bytes32[] hashes - hashes of sibling edges
    function getProof(bytes memory key) public view returns (uint256 branchMask, bytes32[] memory _siblings) {
        D.Label memory k = D.Label(keccak256(key), 256);
        D.Edge memory e = rootEdge;
        bytes32[256] memory siblings;
        uint256 length;
        uint256 numSiblings;
        while (true) {
            (D.Label memory prefix, D.Label memory suffix) = Utils.splitCommonPrefix(k, e.label);
            require(prefix.length == e.label.length, "Prefix lenght mismatch label lenght");
            if (suffix.length == 0) {
                // Found it
                break;
            }
            length += prefix.length;
            branchMask |= uint256(1) << (255 - length);
            length += 1;
            (uint256 head, D.Label memory tail) = Utils.chopFirstBit(suffix);
            siblings[numSiblings++] = edgeHash(nodes[e.node].children[1 - head]);
            e = nodes[e.node].children[head];
            k = tail;
        }
        if (numSiblings > 0) {
            _siblings = new bytes32[](numSiblings);
            for (uint256 i = 0; i < numSiblings; i++) {
                _siblings[i] = siblings[i];
            }
        }
    }

    function getCompactProof(bytes[] memory keys)
        public
        view
        returns (
            bytes32[] memory orderedKeyHashes,
            bytes32[] memory orderedValueHashes,
            uint8[] memory prefixesLengths,
            bytes32[] memory siblings
        )
    {
        orderedKeyHashes = new bytes32[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            orderedKeyHashes[i] = keccak256(keys[i]);
        }

        QuickSort.sort(orderedKeyHashes);

        orderedValueHashes = new bytes32[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            orderedValueHashes[i] = keccak256(keysToValues[orderedKeyHashes[i]]);
        }

        D.Iter memory iter = D.Iter(
            orderedKeyHashes, orderedValueHashes, new uint8[](keys.length*256), new bytes32[](keys.length*256), 0, 0, 0
        );

        D.Label memory key = D.Label(orderedKeyHashes[0], 256);
        getProof(iter, key, rootEdge, 0);

        prefixesLengths = new uint8[](iter.prefixesLengthsOffset);
        for (uint256 i = 0; i < prefixesLengths.length; i++) {
            prefixesLengths[i] = iter.prefixesLengths[i];
        }
        siblings = new bytes32[](iter.siblingsOffset);
        for (uint256 i = 0; i < siblings.length; i++) {
            siblings[i] = iter.siblings[i];
        }

        return (orderedKeyHashes, orderedValueHashes, prefixesLengths, siblings);
    }

    function getProof(D.Iter memory iter, D.Label memory key, D.Edge memory edge, uint256 length) internal view {
        (D.Label memory prefix, D.Label memory suffix) = Utils.splitCommonPrefix(key, edge.label);
        require(prefix.length == edge.label.length, "Prefix length mismatch label lenght");

        if (suffix.length == 0) {
            // Found it
            return;
        }

        length += prefix.length + 1;
        (uint256 head, D.Label memory tail) = Utils.chopFirstBit(suffix);

        getProof(iter, tail, nodes[edge.node].children[head], length);

        iter.prefixesLengths[iter.prefixesLengthsOffset++] = uint8(length - 1);

        if (iter.currentKey == iter.keys.length - 1) {
            iter.siblings[iter.siblingsOffset++] = edgeHash(nodes[edge.node].children[1 - head]);
            return;
        }

        D.Label memory currentKey = D.Label(iter.keys[iter.currentKey], 256);
        D.Label memory nextKey = D.Label(iter.keys[iter.currentKey + 1], 256);
        (prefix, suffix) = Utils.splitCommonPrefix(nextKey, currentKey);

        uint256 newHead;
        (newHead, tail) = Utils.chopFirstBit(suffix);

        if (prefix.length + 1 == length && newHead == 1 - head) {
            iter.currentKey++;
            iter.siblingsOffset++;
            getProof(iter, tail, nodes[edge.node].children[newHead], length);
            iter.prefixesLengths[iter.prefixesLengthsOffset++] = 0;
        } else {
            iter.siblings[iter.siblingsOffset++] = edgeHash(nodes[edge.node].children[1 - head]);
        }
    }

    function verifyProof(
        bytes32 rootHash,
        bytes memory key,
        bytes memory value,
        uint256 branchMask,
        bytes32[] memory siblings
    ) public pure {
        D.Label memory k = D.Label(keccak256(key), 256);
        D.Edge memory e;
        e.node = keccak256(value);
        uint256 b = branchMask;
        for (uint256 i = 0; b != 0; i++) {
            uint256 bitSet = Utils.lowestBitSet(b);
            b &= ~(uint256(1) << bitSet);
            (k, e.label) = Utils.splitAt(k, 255 - bitSet);
            uint256 bit;
            (bit, e.label) = Utils.chopFirstBit(e.label);

            bytes32[2] memory edgeHashes;
            edgeHashes[bit] = edgeHash(e);
            edgeHashes[1 - bit] = siblings[siblings.length - i - 1];
            e.node = keccak256(abi.encodePacked(edgeHashes));
        }
        e.label = k;

        require(rootHash == edgeHash(e), "Bad proof");
    }

    function verifyCompactProof(
        bytes32 rootHash,
        bytes32[] memory keys,
        bytes32[] memory values,
        uint8[] memory prefixesLengths,
        bytes32[] memory siblings
    ) public pure {
        require(keys.length == values.length, "keys and values length mismatch");
        D.Iter memory iter = D.Iter(keys, values, prefixesLengths, siblings, 0, 0, 0);
        bytes32 computedRootHash =
            siblings.length != 0 ? climbTrie(iter, 0, 1) : edgeHash(D.Edge(values[0], D.Label(keys[0], 256)));

        require(iter.currentKey == keys.length - 1, "did not go through all keys");
        require(rootHash == computedRootHash, "Bad proof");
    }

    function climbTrie(D.Iter memory iter, uint256 splitNodePrefixLength, uint8 isRoot)
        internal
        pure
        returns (bytes32)
    {
        D.Label memory k = D.Label(iter.keys[iter.currentKey], 256);
        D.Edge memory e;
        e.node = iter.values[iter.currentKey];
        uint8 prefixLength = iter.prefixesLengths[iter.prefixesLengthsOffset++];
        while (prefixLength != 0 || isRoot == 1) {
            (k, e.label) = Utils.splitAt(k, prefixLength);
            uint256 bit;
            (bit, e.label) = Utils.chopFirstBit(e.label);

            bytes32[2] memory edgeHashes;
            edgeHashes[bit] = edgeHash(e);

            bytes32 currentSibling = iter.siblings[iter.siblingsOffset++];
            if (currentSibling == bytes32(0)) {
                ++iter.currentKey;
                edgeHashes[1 - bit] = climbTrie(iter, prefixLength, 0);
            } else {
                edgeHashes[1 - bit] = currentSibling;
            }

            e.node = keccak256(abi.encodePacked(edgeHashes));
            if (iter.prefixesLengthsOffset == iter.prefixesLengths.length) break;

            prefixLength = iter.prefixesLengths[iter.prefixesLengthsOffset++];
        }

        e.label.data = k.data << (splitNodePrefixLength + 1 - isRoot);
        e.label.length = k.length - (splitNodePrefixLength + 1 - isRoot);

        return edgeHash(e);
    }

    function verifyProofs(
        bytes32 rootHash,
        bytes[] memory keys,
        bytes[] memory values,
        uint256[] memory branchMasks,
        bytes32[][] memory siblings
    ) public pure {
        for (uint256 i = 0; i < keys.length; i++) {
            verifyProof(rootHash, keys[i], values[i], branchMasks[i], siblings[i]);
        }
    }

    function dumpTrie(string memory path) public {
        traverseTrie(rootEdge, D.Label(bytes32(0), 0), path);
    }

    function insertAtNode(bytes32 nodeHash, D.Label memory key, bytes32 value) internal returns (bytes32) {
        require(key.length > 1, "Bad key");
        D.Node memory n = nodes[nodeHash];
        (uint256 head, D.Label memory tail) = Utils.chopFirstBit(key);
        n.children[head] = insertAtEdge(n.children[head], tail, value);
        return replaceNode(nodeHash, n);
    }

    function insertAtEdge(D.Edge memory e, D.Label memory key, bytes32 value) internal returns (D.Edge memory) {
        require(key.length >= e.label.length, "Key lenght mismatch label lenght");
        (D.Label memory prefix, D.Label memory suffix) = Utils.splitCommonPrefix(key, e.label);
        bytes32 newNodeHash;

        if (suffix.length == 0) {
            // Full match with the key, update operation
            newNodeHash = value;
        } else if (prefix.length >= e.label.length) {
            // Partial match, just follow the path
            newNodeHash = insertAtNode(e.node, suffix, value);
        } else {
            // Mismatch, so let us create a new branch node.
            (uint256 head, D.Label memory tail) = Utils.chopFirstBit(suffix);
            D.Node memory branchNode;
            branchNode.children[head] = D.Edge(value, tail);
            branchNode.children[1 - head] = D.Edge(e.node, Utils.removePrefix(e.label, prefix.length + 1));
            newNodeHash = insertNode(branchNode);
        }
        return D.Edge(newNodeHash, prefix);
    }

    function insertNode(D.Node memory n) internal returns (bytes32 newHash) {
        bytes32 h = hash(n);
        nodes[h].children[0] = n.children[0];
        nodes[h].children[1] = n.children[1];
        return h;
    }

    function replaceNode(bytes32 oldHash, D.Node memory n) internal returns (bytes32 newHash) {
        delete nodes[oldHash];
        return insertNode(n);
    }

    function edgeHash(D.Edge memory e) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(e.node, e.label.length, e.label.data));
    }

    // Returns the hash of the encoding of a node.
    function hash(D.Node memory n) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(edgeHash(n.children[0]), edgeHash(n.children[1])));
    }

    function traverseTrie(D.Edge memory e, D.Label memory prefix, string memory path) internal {
        if (e.node == 0 && e.label.length == 0) return;

        string memory edge_ = "edge";
        bytes32 key_ = prefix.data | e.label.data >> prefix.length;
        edge_.serialize("prefix", vm.toString(prefix.data));
        edge_.serialize("prefix.length", vm.toString(prefix.length));
        edge_.serialize("key", vm.toString(key_));
        edge_.serialize("Label.data", vm.toString(e.label.data));
        edge_.serialize("Label.length", vm.toString(e.label.length));
        edge_ = edge_.serialize("Node", vm.toString(e.node));

        vm.writeLine(path, edge_);

        if (prefix.length + e.label.length >= 256) return;

        prefix.data |= e.label.data >> prefix.length;
        prefix.length += e.label.length;

        prefix.length += 1;
        D.Label memory prefixDir0 = D.Label(prefix.data, prefix.length);
        D.Label memory prefixDir1 = D.Label(prefix.data | bytes32(1 << 255 - (prefix.length - 1)), prefix.length);

        traverseTrie(nodes[e.node].children[0], prefixDir0, path);
        traverseTrie(nodes[e.node].children[1], prefixDir1, path);
    }

    function getValue(bytes memory key) public view returns (bytes memory) {
        return keysToValues[keccak256(key)];
    }
}
