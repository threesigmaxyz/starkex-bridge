pragma solidity >=0.5.0;

import { D }     from "src/dependencies/mpt/v2/Data.sol";
import { Utils } from "src/dependencies/mpt/v2/Utils.sol";

library LibMPT {
    function verifyProof(bytes32 rootHash, bytes memory key, bytes memory value, uint branchMask, bytes32[] memory siblings) public pure {
        D.Label memory k = D.Label(keccak256(key), 256);
        D.Edge memory e;
        e.node = keccak256(value);
        uint b = branchMask;
        for (uint i = 0; b != 0; i++) {
            uint bitSet = Utils.lowestBitSet(b);
            b &= ~(uint(1) << bitSet);
            (k, e.label) = Utils.splitAt(k, 255 - bitSet);
            uint bit;
            (bit, e.label) = Utils.chopFirstBit(e.label);
            bytes32[2] memory edgeHashes;
            edgeHashes[bit] = edgeHash(e);
            edgeHashes[1 - bit] = siblings[siblings.length - i - 1];
            e.node = keccak256(abi.encodePacked(edgeHashes));
        }
        e.label = k;
        require(rootHash == edgeHash(e), "Bad proof");
    }

    function edgeHash(D.Edge memory e) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(e.node, e.label.length, e.label.data));
    }
}