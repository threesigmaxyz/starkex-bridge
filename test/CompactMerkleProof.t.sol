// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@forge-std/Test.sol";
import "@forge-std/console.sol";

import "src/dependencies/mpt/compact/CompactMerkleProof.sol";
import "src/dependencies/mpt/compact/common/Nibble.sol";

contract CompactMerkleProofTest is CompactMerkleProof, Test {
    using Input for Input.Data;

    function testSimplePairVerifyProof() public returns (bool) {
        bytes32 root = hex"36d59226dcf98198b07207ee154ebea246a687d8c11191f35b475e7a63f9e5b4";
        bytes[] memory proof = new bytes[](1);
        proof[0] = hex"44646f00";
        bytes[] memory keys = new bytes[](1);
        keys[0] = hex"646f";
        bytes[] memory values = new bytes[](1);
        values[0] = hex"76657262";
        Item[] memory items = new Item[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            items[i] = Item(keys[i], values[i]);
        }
        bool res = verifyProof(root, proof, items);
        assertTrue(res);
		return res;
    }

    function testPairVerifyProof() public returns (bool) {
        bytes32 root = hex"e24f300814d2ddbb2a6ba465cdc2d31004aee7741d0a4964b879f25053b2ed48";
        bytes[] memory merkleProof = new bytes[](3);
        merkleProof[0] = hex"c4646f4000107665726200";
        merkleProof[1] = hex"c107400014707570707900";
        merkleProof[2] = hex"410500";

        bytes[] memory keys = new bytes[](1);
        keys[0] = hex"646f6765";
        bytes[] memory values = new bytes[](1);
        values[0] = hex"0000000000000000000000000000000000000000000000000000000000000000";
        Item[] memory items = new Item[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            items[i] = Item(keys[i], values[i]);
        }
        bool res = verifyProof(root, merkleProof, items);
        assertTrue(res);
		return res;
    }

    function testPairsVerifyProof() public returns (bool) {
        bytes32 root = hex"493825321d9ad0c473bbf85e1a08c742b4a0b75414f890745368b8953b873017";
        bytes[] memory merkleProof = new bytes[](5);
        merkleProof[0] = hex"810616010018487261766f00007c8306f7240030447365207374616c6c696f6e30447365206275696c64696e67";
        merkleProof[1] = hex"466c6661800000000000000000000000000000000000000000000000000000000000000000";
        merkleProof[2] = hex"826f400000";
        merkleProof[3] = hex"8107400000";
        merkleProof[4] = hex"410500";

        //sort keys!
        bytes[] memory keys = new bytes[](8);
        keys[0] = hex"616c6661626574";
        keys[1] = hex"627261766f";
        keys[2] = hex"64";
        keys[3] = hex"646f";
        keys[4] = hex"646f10";
        keys[5] = hex"646f67";
        keys[6] = hex"646f6765";
        keys[7] = hex"68616c70";

        bytes[] memory values = new bytes[](8);
        values[0] = hex"";
        values[1] = hex"627261766f";
        values[2] = hex"";
        values[3] = hex"76657262";
        values[4] = hex"";
        values[5] = hex"7075707079";
        values[6] = hex"0000000000000000000000000000000000000000000000000000000000000000";
        values[7] = hex"";
        Item[] memory items = new Item[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            items[i] = Item(keys[i], values[i]);
        }
        bool res = verifyProof(root, merkleProof, items);
        assertTrue(res);
		return res;
    }

    function testPairsAnotherProof() public returns (bool) {
        bytes32 root = hex"493825321d9ad0c473bbf85e1a08c742b4a0b75414f890745368b8953b873017";
        bytes[] memory merkleProof = new bytes[](3);
        merkleProof[0] = hex"8106160180e1d36480e752f07021a5e11ef480382d11158a5703d3e76df489d0f40c41c4772c487261766f14627261766f007c8306f7240030447365207374616c6c696f6e30447365206275696c64696e67";
        merkleProof[1] = hex"c26f4000107665726200";
        merkleProof[2] = hex"810740008083809f19c0b956a97fc0175e6717d289bb0f890a67a953eb0874f89244314b34";

        //sort keys!
        bytes[] memory keys = new bytes[](1);
        keys[0] = abi.encodePacked("dog");


        bytes[] memory values = new bytes[](1);
        values[0] = abi.encodePacked("puppy");

        Item[] memory items = new Item[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            items[i] = Item(keys[i], values[i]);
        }
        bool res = verifyProof(root, merkleProof, items);
        assertTrue(res);
		return res;
    }

    function testPairsAnotherProof2() public returns (bool) {
        bytes32 root = hex"493825321d9ad0c473bbf85e1a08c742b4a0b75414f890745368b8953b873017";
        bytes[] memory merkleProof = new bytes[](1);
        merkleProof[0] = hex"8106160180e1d36480e752f07021a5e11ef480382d11158a5703d3e76df489d0f40c41c47718487261766f008032d5d23c2ead392b6c8f09de886c981c96e52e133780d15a616333c89ced53c17c8306f7240030447365207374616c6c696f6e30447365206275696c64696e67";

        //sort keys!
        bytes[] memory keys = new bytes[](1);
        keys[0] = abi.encodePacked("bravo");


        bytes[] memory values = new bytes[](1);
        values[0] = abi.encodePacked("bravo");

        Item[] memory items = new Item[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            items[i] = Item(keys[i], values[i]);
        }
        bool res = verifyProof(root, merkleProof, items);
        assertTrue(res);
		return res;
    }

    function testPairsAnotherProof4() public returns (bool) {
        bytes32 root = hex"4ff75de3a99a74fb0d9724d6ce74466dec835957d98006880f59c82ca79d9eb8";
        bytes[] memory merkleProof = new bytes[](1);
        merkleProof[0] = hex"8106160114466c6661002c487261766f14627261766f8032d5d23c2ead392b6c8f09de886c981c96e52e133780d15a616333c89ced53c17c8306f7240030447365207374616c6c696f6e30447365206275696c64696e67";

        //sort keys!
        bytes[] memory keys = new bytes[](1);
        keys[0] = abi.encodePacked("alfa");

        bytes[] memory values = new bytes[](1);
        values[0] = abi.encodePacked(bytes26(0));

        Item[] memory items = new Item[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            items[i] = Item(keys[i], values[i]);
        }
        bool res = verifyProof(root, merkleProof, items);
        assertTrue(res);
		return res;
    }

    function test_decode_leaf() public {
        bytes memory proof = hex"410500";
        Input.Data memory data = Input.from(proof);
        uint8 header = data.decodeU8();
        Node.Leaf memory l = Node.decodeLeaf(data, header);
        assertEq0(l.key, hex"05");
        assertEq0(l.value, hex"");
    }

    function test_encode_leaf() public {
        bytes memory proof = hex"410500";
        Input.Data memory data = Input.from(proof);
        uint8 header = data.decodeU8();
        Node.Leaf memory l = Node.decodeLeaf(data, header);
        bytes memory b = Node.encodeLeaf(l);
        assertEq0(proof, b);
    }

    function test_decode_branch() public {
		bytes memory proof = hex"c10740001470757070798083809f19c0b956a97fc0175e6717d289bb0f890a67a953eb0874f89244314b34";
        Input.Data memory data = Input.from(proof);
        uint8 header = data.decodeU8();
        Node.Branch memory b = Node.decodeBranch(data, header);
        assertEq(b.key, hex"07");
        assertEq0(b.value, hex"7075707079");
        //TODO:: test children
    }

    function test_encode_branch() public {
		bytes memory proof  = hex"c10740001470757070798083809f19c0b956a97fc0175e6717d289bb0f890a67a953eb0874f89244314b34";
        Input.Data memory data = Input.from(proof);
        uint8 header = data.decodeU8();
        Node.Branch memory b = Node.decodeBranch(data, header);
        bytes memory x = Node.encodeBranch(b);
        assertEq0(proof, x);
    }
}
