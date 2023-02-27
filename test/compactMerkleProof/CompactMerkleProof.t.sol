// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { Test } from "@forge-std/Test.sol";
import { CompactMerkleProof } from "src/dependencies/mpt/compact/CompactMerkleProof.sol";
import { Input } from "src/dependencies/mpt/compact/common/Input.sol";
import { Node } from "src/dependencies/mpt/compact/common/Node.sol";
import { console } from "@forge-std/console.sol";
import { stdJson } from "@forge-std/StdJson.sol";

contract CompactMerkleProofTest is Test {
    using Input for Input.Data;
    using stdJson for string;

    struct GeneratorResults {
        string[] keys;
        string[] proof;
        string root;
        string[] values;
    }

    struct VerifierResults {
        bool result;
        string reason;
    }

    /**
     * @dev A child of a node in the tree will be hashed if its data is longer than 32 bytes.
     *         The minimum length of a branch node is 1 byte for the header, 1 byte for the partial key,
     *         2 bytes for the children bitmap, 1 byte for the scale of the children and then the children.
     *         This means that the minimum length of a branch node is 5 bytes + children. Then, a proof can have
     *         1 branch node with 32 / 5 = 6 children inside. So a proof index can have at most depth 7.
     *         This value will be used as an approximation for the size of the stack in the verifier. Later on,
     *         the real depth of the proof should be computed and used instead.
     */
    uint256 private constant MAX_INLINE_NODES_IN_PROOF_INDEX = 7;

    uint256[] private _keysToProve;

    function setUp() public {
        try vm.removeFile("test/compactMerkleProof/differentialTesting/results/allResults.json") { }
            catch (bytes memory) { }
    }

    /**
     * @notice Generates a root and proof from the rust proof generator implementation and then tests
     *            the rust verifier against the solidity verifier. The results are appended to a file.
     *            The keys and values in `keysValues_` are sorted in the rust generator.
     */
    function testVsRustImplementation_SkipCI(bytes[] calldata keysValues_, bytes memory keysToProveMask_) public {
        bytes[] memory keys_ = new bytes[](keysValues_.length);
        bytes[] memory values_ = new bytes[](keysValues_.length);

        for (uint256 i = 0; i < keys_.length; i++) {
            values_[i] = keysValues_[i][0:keysValues_[i].length / 2];
            keys_[i] = keysValues_[i][keysValues_[i].length / 2:keysValues_[i].length];

            // Check if the current key is to be proved
            if (_isKeyToBeProved(keysToProveMask_, i)) _keysToProve.push(i);
        }

        (bytes32 root_, bytes[] memory compactProof_, CompactMerkleProof.Item[] memory itemsToProve_) =
            _generateRootAndProof(keys_, values_, _keysToProve);

        VerifierResults memory rustResult_ = _verifyRootAndProof(root_, compactProof_, itemsToProve_);
        VerifierResults memory solidityResult_;
        try CompactMerkleProof.verifyProof(
            root_, compactProof_, itemsToProve_, compactProof_.length * MAX_INLINE_NODES_IN_PROOF_INDEX
        ) returns (bool res_) {
            solidityResult_ = VerifierResults(res_, "");
        } catch (bytes memory reason) {
            solidityResult_ = VerifierResults(false, _errorToErrorName(reason));
        }

        _appendRunResultsToFile(keys_, values_, root_, compactProof_, itemsToProve_, rustResult_, solidityResult_);

        assertEq(rustResult_.result, solidityResult_.result);
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
        bool res_ = CompactMerkleProof.verifyProof(root_, proof_, items_, proof_.length);
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
        bool res_ = CompactMerkleProof.verifyProof(root_, merkleProof_, items_, merkleProof_.length);
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
        bool res_ = CompactMerkleProof.verifyProof(root_, merkleProof_, items_, merkleProof_.length);
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
        bool res_ = CompactMerkleProof.verifyProof(root_, merkleProof_, items_, merkleProof_.length);
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
        bool res_ = CompactMerkleProof.verifyProof(root_, merkleProof_, items_, merkleProof_.length);
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
        values_[1] = abi.encodePacked("bravo");

        CompactMerkleProof.Item[] memory items_ = _keysValuesToItems(keys_, values_);
        vm.expectRevert(abi.encodeWithSelector(CompactMerkleProof.ExtraneousValueError.selector));
        bool res_ = CompactMerkleProof.verifyProof(root_, merkleProof_, items_, merkleProof_.length);
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
        for (uint256 i_ = 0; i_ < keys_.length; i_++) {
            items_[i_] = CompactMerkleProof.Item(keys_[i_], values_[i_]);
        }
        return items_;
    }

    function _generateRootAndProof(bytes[] memory keys_, bytes[] memory values_, uint256[] memory keysToProve_)
        internal
        returns (bytes32 root_, bytes[] memory compactProof_, CompactMerkleProof.Item[] memory itemsToProve_)
    {
        string[] memory inputs = new string[](6 + 2*keys_.length + 1 + keysToProve_.length);
        inputs[0] = "cargo";
        inputs[1] = "run";
        inputs[2] = "--quiet";
        inputs[3] = "--manifest-path";
        inputs[4] = "test/compactMerkleProof/differentialTesting/Cargo.toml";
        inputs[5] = "generate";
        uint256 currentKeyValuePair_;
        for (uint256 i_ = 0; i_ < 2 * keys_.length; i_ += 2) {
            inputs[6 + i_] = vm.toString(keys_[currentKeyValuePair_]);
            inputs[6 + i_ + 1] = vm.toString(values_[currentKeyValuePair_]);
            currentKeyValuePair_++;
        }
        inputs[6 + 2 * keys_.length] = "keys";

        for (uint256 i_ = 0; i_ < keysToProve_.length; i_++) {
            inputs[6 + 2 * keys_.length + 1 + i_] = vm.toString(keysToProve_[i_]);
        }

        vm.ffi(inputs);
        string memory result_ = vm.readLine("test/compactMerkleProof/differentialTesting/results/generatorResults.json");
        bytes memory parsedResult_ = vm.parseJson(result_);
        GeneratorResults memory generatorResults_ = abi.decode(parsedResult_, (GeneratorResults));
        root_ = bytes32(vm.parseBytes(generatorResults_.root));
        compactProof_ = new bytes[](generatorResults_.proof.length);
        for (uint256 i_ = 0; i_ < compactProof_.length; i_++) {
            compactProof_[i_] = vm.parseBytes(generatorResults_.proof[i_]);
        }

        itemsToProve_ = new CompactMerkleProof.Item[](generatorResults_.keys.length);
        for (uint256 i_ = 0; i_ < generatorResults_.keys.length; i_++) {
            itemsToProve_[i_] = CompactMerkleProof.Item(
                vm.parseBytes(generatorResults_.keys[i_]), vm.parseBytes(generatorResults_.values[i_])
            );
        }
    }

    function _verifyRootAndProof(bytes32 root_, bytes[] memory proof_, CompactMerkleProof.Item[] memory items_)
        internal
        returns (VerifierResults memory)
    {
        string[] memory inputs = new string[](7 + proof_.length + 1 + 2*items_.length);
        inputs[0] = "cargo";
        inputs[1] = "run";
        inputs[2] = "--quiet";
        inputs[3] = "--manifest-path";
        inputs[4] = "test/compactMerkleProof/differentialTesting/Cargo.toml";
        inputs[5] = "verify";

        inputs[6] = vm.toString(root_);

        for (uint256 i_ = 0; i_ < proof_.length; i_++) {
            inputs[7 + i_] = vm.toString(proof_[i_]);
        }
        inputs[7 + proof_.length] = "items";

        uint256 currentItem_;
        for (uint256 i_ = 0; i_ < 2 * items_.length; i_ += 2) {
            inputs[7 + proof_.length + 1 + i_] = vm.toString(items_[currentItem_].key);
            inputs[7 + proof_.length + 1 + i_ + 1] = vm.toString(items_[currentItem_].value);
            currentItem_++;
        }

        vm.ffi(inputs);
        string memory result_ = vm.readFile("test/compactMerkleProof/differentialTesting/results/verifierResults.json");
        if (keccak256(bytes(result_)) == keccak256(bytes("true"))) return VerifierResults(true, "");
        return VerifierResults(false, result_);
    }

    function _isKeyToBeProved(bytes memory keysToProveMask_, uint256 keyAtIndexI_) internal pure returns (bool) {
        if (keyAtIndexI_ / 8 >= keysToProveMask_.length) return false;

        return uint8(bytes1(keysToProveMask_[keyAtIndexI_ / 8])) >> keyAtIndexI_ % 8 & 1 == 1;
    }

    function _bytesArrayToStringArray(bytes[] memory bytesArray_) internal pure returns (string[] memory) {
        string[] memory stringArray_ = new string[](bytesArray_.length);
        for (uint256 i_ = 0; i_ < bytesArray_.length; i_++) {
            stringArray_[i_] = vm.toString(bytesArray_[i_]);
        }
        return stringArray_;
    }

    function _itemsToKeyValues(CompactMerkleProof.Item[] memory items_)
        internal
        pure
        returns (bytes[] memory keys_, bytes[] memory values_)
    {
        keys_ = new bytes[](items_.length);
        values_ = new bytes[](items_.length);
        for (uint256 i_ = 0; i_ < items_.length; i_++) {
            keys_[i_] = items_[i_].key;
            values_[i_] = items_[i_].value;
        }
    }

    function _errorToErrorName(bytes memory error_) internal pure returns (string memory) {
        if (bytes4(error_) == CompactMerkleProof.EmptyProofError.selector) return "EmptyProofError";
        if (bytes4(error_) == CompactMerkleProof.ZeroItemsError.selector) return "ZeroItemsError";
        if (bytes4(error_) == CompactMerkleProof.ExtraneousProofError.selector) return "ExtraneousProofError";
        if (bytes4(error_) == CompactMerkleProof.InvalidRootSizeError.selector) return "InvalidRootSizeError";
        if (bytes4(error_) == CompactMerkleProof.MustBeBranchError.selector) return "MustBeBranchError";
        if (bytes4(error_) == CompactMerkleProof.EmptyChildPrefixError.selector) return "EmptyChildPrefixError";
        if (bytes4(error_) == CompactMerkleProof.InvalidChildReferenceError.selector) {
            return "InvalidChildReferenceError";
        }
        if (bytes4(error_) == CompactMerkleProof.ExtraneousHashReferenceError.selector) {
            return "ExtraneousHashReferenceError";
        }
        if (bytes4(error_) == CompactMerkleProof.IncompleteProofError.selector) return "IncompleteProofError";
        if (bytes4(error_) == CompactMerkleProof.NoValueInLeafError.selector) return "NoValueInLeafError";
        if (bytes4(error_) == CompactMerkleProof.NotFoundError.selector) return "NotFoundError";
        if (bytes4(error_) == CompactMerkleProof.ExtraneousValueError.selector) return "ExtraneousValueError";
        if (bytes4(error_) == CompactMerkleProof.InvalidNodeKindError.selector) return "InvalidNodeKindError";
        if (bytes4(error_) == CompactMerkleProof.DuplicatedKeysError.selector) return "DuplicateKeysError";
        return string(error_);
    }

    function _appendRunResultsToFile(
        bytes[] memory keys_,
        bytes[] memory values_,
        bytes32 root_,
        bytes[] memory compactProof_,
        CompactMerkleProof.Item[] memory itemsToProve_,
        VerifierResults memory rustResult_,
        VerifierResults memory solidityResult_
    ) internal {
        string memory totalVerifierResults_ = "TotalVerifierResults";
        totalVerifierResults_.serialize("Keys", _bytesArrayToStringArray(keys_));
        totalVerifierResults_.serialize("Values", _bytesArrayToStringArray(values_));
        totalVerifierResults_.serialize("Root", vm.toString(root_));
        totalVerifierResults_.serialize("Proof", _bytesArrayToStringArray(compactProof_));
        (bytes[] memory keysToProve_, bytes[] memory valuesToProve_) = _itemsToKeyValues(itemsToProve_);
        string memory itemsToProveObject_ = "ItemsToProve";
        itemsToProveObject_.serialize("Keys", _bytesArrayToStringArray(keysToProve_));
        string memory itemsToProveOutput_ =
            itemsToProveObject_.serialize("Values", _bytesArrayToStringArray(valuesToProve_));
        totalVerifierResults_.serialize("RustVerifierResult", rustResult_.result ? "true" : rustResult_.reason);
        totalVerifierResults_.serialize(
            "SolidityVerifierResult", solidityResult_.result ? "true" : solidityResult_.reason
        );
        totalVerifierResults_ = totalVerifierResults_.serialize(itemsToProveObject_, itemsToProveOutput_);
        vm.writeLine("test/compactMerkleProof/differentialTesting/results/allResults.json", totalVerifierResults_);
    }
}
