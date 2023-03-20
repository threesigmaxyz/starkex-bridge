// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import { D } from "./Data.sol";
import { Utils } from "./Utils.sol";

library LibMPT {
    function verifyProof(
        bytes32 rootHash,
        bytes memory key,
        bytes memory value,
        uint256 branchMask,
        bytes32[] memory siblings
    ) internal pure {
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

    function verifyProofs(
        bytes32 rootHash,
        bytes[] memory keys,
        bytes[] memory values,
        uint256[] memory branchMasks,
        bytes32[][] memory siblings
    ) internal pure {
        for (uint256 i = 0; i < keys.length; i++) {
            verifyProof(rootHash, keys[i], values[i], branchMasks[i], siblings[i]);
        }
    }

    function verifyCompactProof(
        bytes32 rootHash,
        bytes32[] memory keys,
        bytes32[] memory values,
        uint8[] memory prefixesLengths,
        bytes32[] memory siblings
    ) internal pure {
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

    function edgeHash(D.Edge memory e) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(e.node, e.label.length, e.label.data));
    }
}
