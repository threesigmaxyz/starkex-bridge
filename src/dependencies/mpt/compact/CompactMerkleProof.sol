// SPDX-License-Identifier: MIT

// Modified Merkle-Patricia Trie
//
// Note that for the following definitions, `|` denotes concatenation
//
// Branch encoding:
// NodeHeader | Extra partial key length | Partial Key | Value
// `NodeHeader` is a byte such that:
// most significant two bits of `NodeHeader`: 10 if branch w/o value, 11 if branch w/ value
// least significant six bits of `NodeHeader`: if len(key) > 62, 0x3f, otherwise len(key)
// `Extra partial key length` is included if len(key) > 63 and consists of the remaining key length
// `Partial Key` is the branch's key
// `Value` is: Children Bitmap | SCALE Branch node Value | Hash(Enc(Child[i_1])) | Hash(Enc(Child[i_2])) | ... | Hash(Enc(Child[i_n]))
//
// Leaf encoding:
// NodeHeader | Extra partial key length | Partial Key | Value
// `NodeHeader` is a byte such that:
// most significant two bits of `NodeHeader`: 01
// least significant six bits of `NodeHeader`: if len(key) > 62, 0x3f, otherwise len(key)
// `Extra partial key length` is included if len(key) > 63 and consists of the remaining key length
// `Partial Key` is the leaf's key
// `Value` is the leaf's SCALE encoded value

pragma solidity ^0.8.0;

import "./common/Input.sol";
import "./common/Bytes.sol";
import "./common/Nibble.sol";
import "./common/Node.sol";

/**
 * @dev Verification of compact proofs for Modified Merkle-Patricia tries.
 */
contract CompactMerkleProof {
    using Bytes for bytes;
    using Input for Input.Data;

    // Node kinds, no extension
    uint8 internal constant LEAF = 1;
    uint8 internal constant BRANCH_NOVALUE = 2;
    uint8 internal constant BRANCH_WITHVALUE = 3;

    struct StackEntry {
        bytes prefix; // The prefix is the nibble path to the node in the trie.
        uint8 kind; // The type of the trie node.
        bytes key; // The partial key of the trie node.
        bytes value; // The value associated with this trie node.
        Node.NodeHandle[16] children; // The child references to use in reconstructing the trie nodes.
        uint8 childIndex; // The child index is in [0, NIBBLE_LENGTH],
        bool isInline; // The trie node data less 32-byte is an inline node
    }

    struct ProofIter {
        bytes[] proof;
        uint256 offset;
    }

    struct ItemsIter {
        Item[] items;
        uint256 offset;
    }

    struct Item {
        bytes key;
        bytes value;
    }

    enum ValueMatch {Leaf, Branch, NotOmitted, NotFound, IsChild}

    enum Step {Descend, UnwindStack}

    error EmptyProofError();
    error ZeroItemsError();
    error ExtraneousProofError();
    error InvalidRoot_SizeError();
    error MustBeBranchError();
    error EmptyChildPrefixError();
    error InvalidChildReferenceError();
    error ExtraneousHashReferenceError();
    error IncompleteProofError();
    error NoValueInLeafError();
    error ValueInNotFoundError();
    error ExtraneousValueError();
    error InvalidNodeKindError();

	/**
     * @notice Returns true if `keys ans values` can be proved to be a part of a Merkle tree
     * defined by `root_`. For this, a `proof` must be provided, is a sequence of the subset 
     * of nodes in the trie traversed while performing lookups on all keys. The trie nodes 
     * are listed in pre-order traversal order with some values and internal hashes omitted.
     * @param root_ The root hash of the Merkle tree.
     * @param proof_ The proof of the Merkle Patricia trie.
     * @param items_ The items to verify.
     * @return True if the proof is valid, false otherwise.
     */
    function verifyProof(
        bytes32 root_,
        bytes[] memory proof_,
        Item[] memory items_
    ) public pure returns (bool) {
        if (proof_.length == 0) revert EmptyProofError();
        if (items_.length == 0) revert ZeroItemsError();

        StackEntry[] memory stack_ = new StackEntry[](proof_.length);
        uint256 stackLen_;
        StackEntry memory lastEntry_ = decodeNode(proof_[0], hex"", false);
        ProofIter memory proofIter_ = ProofIter({proof: proof_, offset: 1});
        ItemsIter memory itemsIter_ = ItemsIter({items: items_, offset: 0});
        bytes memory childRef_;
        Step step_;
        bytes memory childPrefix_;
        bytes memory nodeData_;
        while (true) {
            (step_, childPrefix_) = advanceItem(lastEntry_, itemsIter_);
            if (step_ == Step.Descend) {
                stack_[stackLen_++] = lastEntry_;
                lastEntry_ = advanceChildIndex(lastEntry_, childPrefix_, proofIter_);
                continue;
            } 
            // step == Step.UnwindStack
            nodeData_ = encodeNode(lastEntry_);
            if (lastEntry_.isInline && nodeData_.length > 32) revert("invalid child reference");

            lastEntry_.isInline ? childRef_ = nodeData_ : childRef_ = Hash.hash(nodeData_);
        
            if (stackLen_ == 0) break;

            lastEntry_ = stack_[--stackLen_];
            lastEntry_.children[lastEntry_.childIndex].data = childRef_;                
        }

        if(proofIter_.offset != proof_.length) revert ExtraneousProofError();
        if(childRef_.length != 32) revert InvalidRoot_SizeError();
        if (abi.decode(childRef_, (bytes32)) != root_) return false;
        return true;
    }

    /**
     * @notice Advances to the next child index and returns the child entry.
     * @dev The child index is the last nibble of the child prefix.
     * @param entry_ The stack entry.
     * @param childPrefix_ The child prefix.
     * @param proofIter_ The proof iterator.
     */
    function advanceChildIndex(
        StackEntry memory entry_,
        bytes memory childPrefix_,
        ProofIter memory proofIter_
    ) internal pure returns (StackEntry memory) {
        if (entry_.kind != BRANCH_NOVALUE && entry_.kind != BRANCH_WITHVALUE) revert MustBeBranchError();
        if (childPrefix_.length == 0) revert EmptyChildPrefixError();

        entry_.childIndex = uint8(childPrefix_[childPrefix_.length - 1]);
        Node.NodeHandle memory child_ = entry_.children[entry_.childIndex];
        return makeChildEntry(proofIter_, child_, childPrefix_);
    }

    /**
     * @notice Returns a node either from the next proof iter or the inline childData.
     * @param proofIter_ The proof iterator.
     * @param child_ The child node handle.
     * @param prefix_ The prefix of the child node.
     * @return StackEntry The decoded child node.
     */
    function makeChildEntry(
        ProofIter memory proofIter_,
        Node.NodeHandle memory child_,
        bytes memory prefix_
    ) internal pure returns (StackEntry memory) {
        if (!child_.isInline){
            if (child_.data.length != 32) revert InvalidChildReferenceError();
            revert ExtraneousHashReferenceError();
        } 

        // Return decoded inline child from branch  
        if(child_.data.length > 0) return decodeNode(child_.data, prefix_, true);
        
        // Return decoded inline child from proof
        if(proofIter_.offset >= proofIter_.proof.length) revert IncompleteProofError();

        bytes memory nodeData_ = proofIter_.proof[proofIter_.offset];
        proofIter_.offset++;
        return decodeNode(nodeData_, prefix_, false);
    }

    /**
     * @notice Returns the next item to process and the child prefix to descend to.
     * @param entry_ The current stack entry.
     * @param itemsIter_ The iterator over the items to prove.
     * @return step_ The next step to take.
     * @return childPrefix_ The child prefix to descend to.
     */
    function advanceItem(StackEntry memory entry_, ItemsIter memory itemsIter_) internal pure
        returns (Step, bytes memory childPrefix_)
    {
        ValueMatch vm_;
        while (itemsIter_.offset < itemsIter_.items.length) {
            Item memory item_ = itemsIter_.items[itemsIter_.offset];
            bytes memory keyAsNibbles_ = Nibble.keyToNibbles(item_.key);

            if (!startsWith(keyAsNibbles_, entry_.prefix)) return (Step.UnwindStack, "");
            
            (vm_, childPrefix_) = matchKeyToNode(keyAsNibbles_, entry_.prefix.length, entry_);

            if (vm_ == ValueMatch.Leaf && item_.value.length == 0) revert NoValueInLeafError();
            if (vm_ == ValueMatch.NotFound && item_.value.length > 0) revert ValueInNotFoundError();
            if (vm_ == ValueMatch.NotOmitted) revert ExtraneousValueError();
            if (vm_ == ValueMatch.IsChild) return (Step.Descend, childPrefix_);
            if (vm_ != ValueMatch.NotFound) entry_.value = item_.value;

            itemsIter_.offset++;
        }
        return (Step.UnwindStack, childPrefix_);
    }

    /**
     * @notice Matches a key to a node in entry.
     * @param keyAsNibbles_ The key to match.
     * @param prefixLen_ The length of the prefix.
     * @param entry_ The node to match against.
     * @return ValueMatch The result of the match.
     * @return bytes The child prefix if the match is ValueMatch.IsChild.
     */
    function matchKeyToNode(bytes memory keyAsNibbles_, uint256 prefixLen_, StackEntry memory entry_) internal pure
        returns (ValueMatch, bytes memory) 
    {
        if (!_isNodeKindSupported(entry_.kind)) revert InvalidNodeKindError();

        uint256 prefixPlusPartialLen = prefixLen_ + entry_.key.length;

        if (entry_.kind == LEAF) {
            if (!contains(keyAsNibbles_, entry_.key, prefixLen_) || keyAsNibbles_.length != prefixPlusPartialLen) 
                return (ValueMatch.NotFound, "");

            return(entry_.value.length == 0 ? ValueMatch.Leaf : ValueMatch.NotOmitted, "");
        } 

        if (!contains(keyAsNibbles_, entry_.key, prefixLen_)) return (ValueMatch.NotFound, "");

        if (prefixPlusPartialLen == keyAsNibbles_.length) 
            return (entry_.value.length == 0 ? ValueMatch.Branch : ValueMatch.NotOmitted, "");
        
        uint8 index = uint8(keyAsNibbles_[prefixPlusPartialLen]);
        if (!entry_.children[index].exist) return (ValueMatch.NotFound, "");

        bytes memory childPrefix_ = keyAsNibbles_.substr(0, prefixPlusPartialLen + 1);
        return (ValueMatch.IsChild, childPrefix_);
    }

    /**
     * @notice Check if a bytes array contains another bytes array at a given offset.
     * @param a_ The bytes array to check.
     * @param b_ The bytes array to check against.
     * @param offset_ The offset to check at.
     * @return true If a_ contains b_ at offset_, false otherwise.
     */
    function contains(bytes memory a_, bytes memory b_, uint256 offset_) internal pure returns (bool) {
        if (a_.length < b_.length + offset_) return false;
        
        for (uint256 i = 0; i < b_.length; i++) {
            if (a_[i + offset_] != b_[i]) return false;
        }
        return true;
    }

    /**
     * @notice Check if a bytes array starts with another bytes array.
     * @param a_ The bytes array to check.
     * @param b_ The bytes array to check against.
     * @return true If a_ starts with b_, false otherwise.
     */
    function startsWith(bytes memory a_, bytes memory b_) internal pure returns (bool) {
        if (a_.length < b_.length) return false;
        
        for (uint256 i = 0; i < b_.length; i++) {
            if (a_[i] != b_[i]) return false;   
        }
        return true;
    }

    /**
     * @dev Encode a Node.
     *      encoding has the following format:
     *      NodeHeader | Extra partial key length | Partial Key | Value
     * @param entry_ The stackEntry.
     * @return bytes The encoded branch.
     */
    function encodeNode(StackEntry memory entry_) internal pure returns (bytes memory) {
        if (!_isNodeKindSupported(entry_.kind)) revert InvalidNodeKindError();

        if (entry_.kind == LEAF) return Node.encodeLeaf(Node.Leaf(entry_.key, entry_.value));

        return Node.encodeBranch(Node.Branch(entry_.key, entry_.children, entry_.value));
    }

    /**
     * @dev Decode a Node.
     *      encoding has the following format:
     *      NodeHeader | Extra partial key length | Partial Key | Value
     * @param nodeData_ The encoded trie node data.
     * @param prefix_ The nibble path to the node.
     * @param isInline_ The node is an in-line node or not.
     * @return entry_ The StackEntry.
     */
    function decodeNode(bytes memory nodeData_, bytes memory prefix_, bool isInline_
    ) internal pure returns (StackEntry memory entry_) {
        Input.Data memory data_ = Input.from(nodeData_); // nodeData to Data {uint256 offset = 0, bytes raw = nodeData}
        uint8 header_ = data_.decodeU8(); // Get the first byte of nodeData (header) and increase offset to 1
        uint8 kind_ = header_ >> 6; // Get the first two bits of header
        if (!_isNodeKindSupported(kind_)) revert InvalidNodeKindError();

        entry_.kind = kind_;
        entry_.prefix = prefix_;
        entry_.isInline = isInline_;
        
        if (kind_ == LEAF) { 
            Node.Leaf memory leaf_ = Node.decodeLeaf(data_, header_);
            entry_.key = leaf_.key;
            entry_.value = leaf_.value;
            return entry_;
        } 

        Node.Branch memory branch_ = Node.decodeBranch(data_, header_);
        entry_.key = branch_.key;
        entry_.value = branch_.value;
        entry_.children = branch_.children;
        entry_.childIndex = 0;
    }

    /**
     * @notice Check if the node kind is supported.
     * @param kind_ The node kind.
     * @return true If the node kind is supported, false otherwise.
     */ 
    function _isNodeKindSupported(uint8 kind_) internal pure returns(bool) {
        return kind_ == LEAF || kind_ == BRANCH_NOVALUE || kind_ == BRANCH_WITHVALUE;
    }
}
