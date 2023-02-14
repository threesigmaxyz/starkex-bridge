// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { Test } from "@forge-std/Test.sol";
import { CompactMerkleProof } from "src/dependencies/mpt/compact/CompactMerkleProof.sol";
import { Input } from "src/dependencies/mpt/compact/common/Input.sol";
import { Node } from "src/dependencies/mpt/compact/common/Node.sol";
import { console } from "@forge-std/console.sol";

contract CompactMerkleProofTest is Test {
    using Input for Input.Data;

    struct GeneratorResults {
        string[] proof;
        string root;
    }

    uint256[] private _keysToProve;

    function testVsRustImplementation(bytes[] calldata keysValues_, bytes memory keysToProveMask_) public {
        vm.assume(keysValues_.length > 0);

        bytes[] memory keys_ = new bytes[](keysValues_.length);
        bytes[] memory values_ = new bytes[](keysValues_.length);

        for (uint i = 0; i < keys_.length; i++) {
            values_[i] = keysValues_[i][0 : keysValues_[i].length/2];
            keys_[i] = keysValues_[i][keysValues_[i].length/2 : keysValues_[i].length];

            // Check if the current key is to be proved
            if (_isKeyToBeProved(keysToProveMask_, i)) _keysToProve.push(i);

            if (i > 0) keys_[i] = _addBytes(keys_[i], keys_[i-1]);
        }
        
        (bytes32 root_, bytes[] memory compactProof_) = _generateRootAndProof(keys_, values_, _keysToProve);
        bool rustRes_ = _verifyRootAndProof(root_, compactProof_, _keysValuesToItems(keys_, values_, _keysToProve));
        try CompactMerkleProof.verifyProof(root_, compactProof_, _keysValuesToItems(keys_, values_, _keysToProve)) returns (bool res_) {
            assertEq(rustRes_, res_);
        } catch (bytes memory reason) {
            console.log("Error: ", vm.toString(reason));
            assertEq(rustRes_, false);
        }
    }

    function testCustom() public {
        bytes32 root_ = hex"d982ceabee899d9c01f5c83b3fc37e2821c1a7686e38b8ae8db9abb94ba2d37a";
        bytes[] memory compactProof_ = new bytes[](1);
        compactProof_[0] = hex"bf098a8e6a00000000000000000000000000000000000000000000000000000000000000000001041c470000000104004c81048010204507f33d0c0dd465144504d45100";
        CompactMerkleProof.Item[] memory items_ = new CompactMerkleProof.Item[](2);
        items_[0] = CompactMerkleProof.Item(hex"8a8e6a00000000000000000000000000000000000000000000000000000000000000000000000000", "");
        items_[1] = CompactMerkleProof.Item(hex"8a8e6a000000000000000000000000000000000000000000000000000000000000000000a4c4d451", hex"7b6a");
        CompactMerkleProof.verifyProof(root_, compactProof_, items_);
    }

    function testSelectors() public {
        console.logBytes4(CompactMerkleProof.EmptyProofError.selector);
        console.logBytes4(CompactMerkleProof.ZeroItemsError.selector);
        console.logBytes4(CompactMerkleProof.ExtraneousProofError.selector);
        console.logBytes4(CompactMerkleProof.InvalidRootSizeError.selector);
        console.logBytes4(CompactMerkleProof.MustBeBranchError.selector);
        console.logBytes4(CompactMerkleProof.EmptyChildPrefixError.selector);
        console.logBytes4(CompactMerkleProof.InvalidChildReferenceError.selector);
        console.logBytes4(CompactMerkleProof.ExtraneousHashReferenceError.selector);
        console.logBytes4(CompactMerkleProof.IncompleteProofError.selector);
        console.logBytes4(CompactMerkleProof.NoValueInLeafError.selector);
        console.logBytes4(CompactMerkleProof.ValueInNotFoundError.selector);
        console.logBytes4(CompactMerkleProof.ExtraneousValueError.selector);
        console.logBytes4(CompactMerkleProof.InvalidNodeKindError.selector);
    }

    function testGeneratorAndVerifierFfiCalls() public {
        bytes[] memory keys_ = new bytes[](2);
        keys_[0] = hex"1234";
        keys_[1] = abi.encodePacked(keccak256(abi.encodePacked(bytes1(uint8(1)))));
        bytes[] memory values_ = new bytes[](2);
        values_[0] = hex"5678";
        values_[1] = hex"5679";
        uint256[] memory keysToProve_ = new uint256[](2);
        keysToProve_[0] = 0;
        keysToProve_[1] = 1;

        (bytes32 root_, bytes[] memory compactProof_) = _generateRootAndProof(keys_, values_, keysToProve_);
        
        assertEq(root_, hex"b9fe0c74ca49700a23570a0be4f7f1a30386cde4381248890f29960ec7f33584");
        assertEq(compactProof_.length, 2);
        assertEq(keccak256(compactProof_[0]), keccak256(hex"802200104302340000"));
        assertEq(keccak256(compactProof_[1]), keccak256(hex"7f000fe7f977e71dba2ea1a68e21057beebb9be2ac30c6410aa38d4f3fbe41dcffd200"));

        bool res = _verifyRootAndProof(root_, compactProof_, _keysValuesToItems(keys_, values_, keysToProve_));
        assertEq(res, true);
    }

    function testGeneratorAndVerifierFfiCalls2() public {
        bytes[] memory keys_ = new bytes[](2);
        keys_[0] = hex"100000000000000000000000000000";
        keys_[1] = hex"000000000000000000100000000000000000000000000000";
        bytes[] memory values_ = new bytes[](2);
        values_[0] = hex"000000000000000000000000000000";
        values_[1] = hex"000000000000000000000000000000000000000000000000";
        uint256[] memory keysToProve_ = new uint256[](2);
        keysToProve_[0] = 0;
        keysToProve_[1] = 1;

        (bytes32 root_, bytes[] memory compactProof_) = _generateRootAndProof(keys_, values_, keysToProve_);
    
        bool res = _verifyRootAndProof(root_, compactProof_, _keysValuesToItems(keys_, values_, keysToProve_));
        assertEq(res, true);
    }

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

    function testAddBytes(bytes memory number1_, bytes memory number2_) public {
        vm.assume(number1_.length <= 32);
        vm.assume(number2_.length <= 32);
        uint256 number1val_ = bytesToUint(number1_);
        uint256 number2val_ = bytesToUint(number2_);
  
        vm.assume(number2val_ <= type(uint256).max - number1val_);
        uint256 expectedResult_ = number1val_ + number2val_;
        uint256 result_ = bytesToUint(_addBytes(number1_, number2_));
        assertEq(result_, expectedResult_);
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

    function _keysValuesToItems(bytes[] memory keys_, bytes[] memory values_, uint256[] memory keysToProve_)
        internal
        pure
        returns (CompactMerkleProof.Item[] memory)
    {
        CompactMerkleProof.Item[] memory items_ = new CompactMerkleProof.Item[](keysToProve_.length);
        for (uint256 i_ = 0; i_ < keysToProve_.length; i_++) {
            items_[i_] = CompactMerkleProof.Item(keys_[keysToProve_[i_]], values_[keysToProve_[i_]]);
        }
        return items_;
    }

    function _generateRootAndProof(bytes[] memory keys_, bytes[] memory values_, uint256[] memory keysToProve_
    ) internal returns (bytes32 root_, bytes[] memory compactProof_) {
        string[] memory inputs = new string[](6 + 2*keys_.length + 1 + keysToProve_.length);
        inputs[0] = "cargo";
        inputs[1] = "run";
        inputs[2] = "--quiet";
        inputs[3] = "--manifest-path";
        inputs[4] = "test/compactMerkleProof/differentialTesting/Cargo.toml";
        inputs[5] = "generate";
        uint256 currentKeyValuePair_;
        for (uint i = 0; i < 2*keys_.length; i+=2) {
            inputs[6 + i] = vm.toString(keys_[currentKeyValuePair_]);
            inputs[6 + i + 1] = vm.toString(values_[currentKeyValuePair_]);
            currentKeyValuePair_++;
        }
        inputs[6 + 2*keys_.length] = "keys";

        for (uint i = 0; i < keysToProve_.length; i++) {
            inputs[6 + 2*keys_.length + 1 + i] = vm.toString(keys_[keysToProve_[i]]);
        }

        vm.ffi(inputs);
        string memory result_ = vm.readFile("test/compactMerkleProof/differentialTesting/results/generatorResults.txt");
        bytes memory parsedResult_ = vm.parseJson(result_);
        GeneratorResults memory generatorResults_ = abi.decode(parsedResult_, (GeneratorResults));
        root_ = bytes32(vm.parseBytes(generatorResults_.root));
        compactProof_ = new bytes[](generatorResults_.proof.length);
        for (uint i = 0; i < compactProof_.length; i++) {
            compactProof_[i] = vm.parseBytes(generatorResults_.proof[i]);
        }
    }

    function _verifyRootAndProof(bytes32 root_, bytes[] memory proof_, CompactMerkleProof.Item[] memory items_
    ) internal returns (bool) {
        string[] memory inputs = new string[](7 + proof_.length + 1 + 2*items_.length);
        inputs[0] = "cargo";
        inputs[1] = "run";
        inputs[2] = "--quiet";
        inputs[3] = "--manifest-path";
        inputs[4] = "test/compactMerkleProof/differentialTesting/Cargo.toml";
        inputs[5] = "verify";

        inputs[6] = vm.toString(root_);

        for (uint i = 0; i < proof_.length; i++) {
            inputs[7 + i] = vm.toString(proof_[i]);
        }
        inputs[7 + proof_.length] = "items";

        uint256 currentItem_;
        for (uint i = 0; i < 2*items_.length; i+=2) {
            inputs[7 + proof_.length + 1 + i] = vm.toString(items_[currentItem_].key);
            inputs[7 + proof_.length + 1 + i + 1] = vm.toString(items_[currentItem_].value);
            currentItem_++;
        }

        vm.ffi(inputs);
        string memory result_ = vm.readFile("test/compactMerkleProof/differentialTesting/results/verifierResults.txt");
        if (keccak256(bytes(result_)) == keccak256(bytes("true"))) return true;
        console.log(result_);
        return false;
    }

    function _isKeyToBeProved(bytes memory keysToProveMask_, uint256 keyAtIndexI_) internal pure returns (bool) {
        if (keyAtIndexI_/8 >= keysToProveMask_.length) return false;

        return uint8(bytes1(keysToProveMask_[keyAtIndexI_/8])) >> keyAtIndexI_ % 8 & 1 == 1;
    }

    function _addBytes(bytes memory array1_, bytes memory array2_) internal pure returns (bytes memory) {
        uint256 smallestArrayLength_ = array1_.length < array2_.length ? array1_.length : array2_.length;
        bytes memory longestArray_ = array2_.length > array1_.length ? array2_ : array1_;
        bytes memory result_ = new bytes(longestArray_.length);

        uint i_ = 1;
        uint16 sumWithCarry_;
        while (i_ <= smallestArrayLength_) {
            sumWithCarry_ += uint16(uint8(array1_[array1_.length - i_])) + uint8(array2_[array2_.length - i_]);
            unchecked {
                result_[result_.length - i_] = bytes1(uint8(sumWithCarry_));
            }
            sumWithCarry_ = sumWithCarry_ > uint16(uint8(result_[result_.length - i_])) ? 1 : 0;
            ++i_;
        }
        while (i_ <= longestArray_.length) {
            sumWithCarry_ += uint8(longestArray_[longestArray_.length - i_]);
            unchecked {
                result_[result_.length - i_] = bytes1(uint8(sumWithCarry_));
            }
            sumWithCarry_ = sumWithCarry_ > uint16(uint8(result_[result_.length - i_])) ? 1 : 0;
            ++i_;
        }

        if (sumWithCarry_ == 1) result_ = abi.encodePacked(hex"01", result_);

        return result_;
    }
}
