// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { Test } from "@forge-std/Test.sol";
import { CompactMerkleProof } from "src/dependencies/mpt/compact/CompactMerkleProof.sol";
import { Input } from "src/dependencies/mpt/compact/common/Input.sol";
import { Node } from "src/dependencies/mpt/compact/common/Node.sol";

contract CompactMerkleProofTest is Test {
    using Input for Input.Data;

    function testSimplePairVerifyProof() public {
        bytes32 root_ = hex"36d59226dcf98198b07207ee154ebea246a687d8c11191f35b475e7a63f9e5b4";
        bytes[] memory proof_ = new bytes[](1);
        proof_[0] = hex"44646f00";
        bytes[] memory keys_ = new bytes[](1);
        keys_[0] = hex"646f";
        bytes[] memory values_ = new bytes[](1);
        values_[0] = hex"76657262";
        CompactMerkleProof.Item[] memory items_ = _keysValuesToItems(keys_, values_);
        bool res_ = CompactMerkleProof.verifyProof(root_, proof_, items_);
        assertTrue(res_);
    }

    function testPairVerifyProof() public {
        bytes32 root_ = hex"e24f300814d2ddbb2a6ba465cdc2d31004aee7741d0a4964b879f25053b2ed48";
        bytes[] memory merkleProof_ = new bytes[](3);
        merkleProof_[0] = hex"c4646f4000107665726200";
        merkleProof_[1] = hex"c107400014707570707900";
        merkleProof_[2] = hex"410500";

        bytes[] memory keys_ = new bytes[](1);
        keys_[0] = hex"646f6765";
        bytes[] memory values_ = new bytes[](1);
        values_[0] = hex"0000000000000000000000000000000000000000000000000000000000000000";
        CompactMerkleProof.Item[] memory items_ = _keysValuesToItems(keys_, values_);
        bool res_ = CompactMerkleProof.verifyProof(root_, merkleProof_, items_);
        assertTrue(res_);
    }

    function testPairsVerifyProof() public {
        bytes32 root_ = hex"493825321d9ad0c473bbf85e1a08c742b4a0b75414f890745368b8953b873017";
        bytes[] memory merkleProof_ = new bytes[](5);
        merkleProof_[0] =
            hex"810616010018487261766f00007c8306f7240030447365207374616c6c696f6e30447365206275696c64696e67";
        merkleProof_[1] = hex"466c6661800000000000000000000000000000000000000000000000000000000000000000";
        merkleProof_[2] = hex"826f400000";
        merkleProof_[3] = hex"8107400000";
        merkleProof_[4] = hex"410500";

        //sort keys!
        bytes[] memory keys_ = new bytes[](8);
        keys_[0] = hex"616c6661626574";
        keys_[1] = hex"627261766f";
        keys_[2] = hex"64";
        keys_[3] = hex"646f";
        keys_[4] = hex"646f10";
        keys_[5] = hex"646f67";
        keys_[6] = hex"646f6765";
        keys_[7] = hex"68616c70";

        bytes[] memory values_ = new bytes[](8);
        values_[0] = hex"";
        values_[1] = hex"627261766f";
        values_[2] = hex"";
        values_[3] = hex"76657262";
        values_[4] = hex"";
        values_[5] = hex"7075707079";
        values_[6] = hex"0000000000000000000000000000000000000000000000000000000000000000";
        values_[7] = hex"";
        CompactMerkleProof.Item[] memory items_ = _keysValuesToItems(keys_, values_);
        bool res_ = CompactMerkleProof.verifyProof(root_, merkleProof_, items_);
        assertTrue(res_);
    }

    function testPairsAnotherProof() public {
        bytes32 root_ = hex"493825321d9ad0c473bbf85e1a08c742b4a0b75414f890745368b8953b873017";
        bytes[] memory merkleProof_ = new bytes[](3);
        merkleProof_[0] =
            hex"8106160180e1d36480e752f07021a5e11ef480382d11158a5703d3e76df489d0f40c41c4772c487261766f14627261766f007c8306f7240030447365207374616c6c696f6e30447365206275696c64696e67";
        merkleProof_[1] = hex"c26f4000107665726200";
        merkleProof_[2] = hex"810740008083809f19c0b956a97fc0175e6717d289bb0f890a67a953eb0874f89244314b34";

        //sort keys!
        bytes[] memory keys_ = new bytes[](1);
        keys_[0] = abi.encodePacked("dog");

        bytes[] memory values_ = new bytes[](1);
        values_[0] = abi.encodePacked("puppy");

        CompactMerkleProof.Item[] memory items_ = _keysValuesToItems(keys_, values_);
        bool res_ = CompactMerkleProof.verifyProof(root_, merkleProof_, items_);
        assertTrue(res_);
    }

    function testPairsAnotherProof2() public {
        bytes32 root_ = hex"493825321d9ad0c473bbf85e1a08c742b4a0b75414f890745368b8953b873017";
        bytes[] memory merkleProof_ = new bytes[](1);
        merkleProof_[0] =
            hex"8106160180e1d36480e752f07021a5e11ef480382d11158a5703d3e76df489d0f40c41c47718487261766f008032d5d23c2ead392b6c8f09de886c981c96e52e133780d15a616333c89ced53c17c8306f7240030447365207374616c6c696f6e30447365206275696c64696e67";

        //sort keys!
        bytes[] memory keys_ = new bytes[](1);
        keys_[0] = abi.encodePacked("bravo");

        bytes[] memory values_ = new bytes[](1);
        values_[0] = abi.encodePacked("bravo");

        CompactMerkleProof.Item[] memory items_ = _keysValuesToItems(keys_, values_);
        bool res_ = CompactMerkleProof.verifyProof(root_, merkleProof_, items_);
        assertTrue(res_);
    }

    function testPairsAnotherProof3() public {
        bytes32 root_ = hex"4ff75de3a99a74fb0d9724d6ce74466dec835957d98006880f59c82ca79d9eb8";
        bytes[] memory merkleProof_ = new bytes[](1);
        merkleProof_[0] =
            hex"8106160114466c6661002c487261766f14627261766f8032d5d23c2ead392b6c8f09de886c981c96e52e133780d15a616333c89ced53c17c8306f7240030447365207374616c6c696f6e30447365206275696c64696e67";

        //sort keys!
        bytes[] memory keys_ = new bytes[](1);
        keys_[0] = abi.encodePacked("alfa");

        bytes[] memory values_ = new bytes[](1);
        values_[0] = abi.encodePacked(bytes26(0));

        CompactMerkleProof.Item[] memory items_ = _keysValuesToItems(keys_, values_);
        bool res_ = CompactMerkleProof.verifyProof(root_, merkleProof_, items_);
        assertTrue(res_);
    }

    function testDuplicatedKeyReverts() public {
        bytes32 root_ = hex"493825321d9ad0c473bbf85e1a08c742b4a0b75414f890745368b8953b873017";
        bytes[] memory merkleProof_ = new bytes[](1);
        merkleProof_[0] =
            hex"8106160180e1d36480e752f07021a5e11ef480382d11158a5703d3e76df489d0f40c41c47718487261766f008032d5d23c2ead392b6c8f09de886c981c96e52e133780d15a616333c89ced53c17c8306f7240030447365207374616c6c696f6e30447365206275696c64696e67";

        //sort keys!
        bytes[] memory keys_ = new bytes[](2);
        keys_[0] = abi.encodePacked("bravo");
        keys_[1] = abi.encodePacked("bravo");

        bytes[] memory values_ = new bytes[](2);
        values_[0] = abi.encodePacked("bravo");
        values_[0] = abi.encodePacked("bravo");

        CompactMerkleProof.Item[] memory items_ = _keysValuesToItems(keys_, values_);
        vm.expectRevert(abi.encodeWithSelector(CompactMerkleProof.ExtraneousValueError.selector));
        bool res_ = CompactMerkleProof.verifyProof(root_, merkleProof_, items_);
        assertFalse(res_);
    }

    function testDecodeLeaf() public {
        bytes memory proof_ = hex"410500";
        Input.Data memory data_ = Input.from(proof_);
        uint8 header_ = data_.decodeU8();
        Node.Leaf memory leaf_ = Node.decodeLeaf(data_, header_);
        assertEq0(leaf_.key, hex"05");
        assertEq0(leaf_.value, hex"");
    }

    function testEncodeLeaf() public {
        bytes memory proof_ = hex"410500";
        Input.Data memory data_ = Input.from(proof_);
        uint8 header_ = data_.decodeU8();
        Node.Leaf memory leaf_ = Node.decodeLeaf(data_, header_);
        bytes memory branch_ = Node.encodeLeaf(leaf_);
        assertEq0(proof_, branch_);
    }

    function testDecodeBranch() public {
        bytes memory proof_ =
            hex"c10740001470757070798083809f19c0b956a97fc0175e6717d289bb0f890a67a953eb0874f89244314b34";
        Input.Data memory data_ = Input.from(proof_);
        uint8 header_ = data_.decodeU8();
        Node.Branch memory branch_ = Node.decodeBranch(data_, header_);
        assertEq(branch_.key, hex"07");
        assertEq0(branch_.value, hex"7075707079");
        //TODO:: test children
    }

    function testEncodeBranch() public {
        bytes memory proof_ =
            hex"c10740001470757070798083809f19c0b956a97fc0175e6717d289bb0f890a67a953eb0874f89244314b34";
        Input.Data memory data_ = Input.from(proof_);
        uint8 header_ = data_.decodeU8();
        Node.Branch memory branch_ = Node.decodeBranch(data_, header_);
        bytes memory encodedBranch_ = Node.encodeBranch(branch_);
        assertEq0(proof_, encodedBranch_);
    }

    function _keysValuesToItems(bytes[] memory keys_, bytes[] memory values_)
        internal
        pure
        returns (CompactMerkleProof.Item[] memory)
    {
        CompactMerkleProof.Item[] memory items_ = new CompactMerkleProof.Item[](keys_.length);
        for (uint256 i = 0; i < keys_.length; i++) {
            items_[i] = CompactMerkleProof.Item(keys_[i], values_[i]);
        }
        return items_;
    }
}
