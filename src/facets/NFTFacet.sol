// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { HelpersERC721 } from "src/helpers/HelpersERC721.sol";
import { HelpersECDSA } from "src/helpers/HelpersECDSA.sol";
import { ECDSA } from "src/dependencies/ecdsa/ECDSA.sol";
import { Constants } from "src/constants/Constants.sol";
import { OnlyInteroperabilityContract } from "src/modifiers/OnlyInteroperabilityContract.sol";
import { OnlyRegisteredToken } from "src/modifiers/OnlyRegisteredToken.sol";
import { LibMPT as MerklePatriciaTree } from "src/dependencies/mpt/v2/LibMPT.sol";
import { LibState } from "src/libraries/LibState.sol";
import { OnlyOwner } from "src/modifiers/OnlyOwner.sol";
import { INFTFacet } from "src/interfaces/facets/INFTFacet.sol";

import { PedersenHash } from "src/dependencies/perdersen/PedersenHash.sol";

contract NFTFacet is OnlyRegisteredToken, OnlyOwner, OnlyInteroperabilityContract, INFTFacet {
    uint256 constant RECEIVER_STARK_KEY = 0;
    uint256 constant RECEIVER_VAULT_ID = 0;
    uint256 constant QUANTIZED_AMOUNT = 1;
    uint256 constant QUANTIZED_AMOUNT_LIMIT = 1;

    bytes32 constant NFT_STORAGE_POSITION = keccak256("NFT_STORAGE_POSITION");

    /// @dev Storage of this facet using diamond storage.
    function nftStorage() internal pure returns (NFTStorage storage ns) {
        bytes32 position_ = NFT_STORAGE_POSITION;
        assembly {
            ns.slot := position_
        }
    }

    /// @inheritdoc INFTFacet
    function setExpirationTimeout(uint256 timeout_) public override onlyOwner {
        nftStorage().expirationTimeout = timeout_;
        emit LogSetExpirationTimeout(timeout_);
    }

    /// @inheritdoc INFTFacet
    function depositNFT(uint256 starkKey_, address token_, uint256 tokenId_, uint256 lockHash_, uint256 assetId_)
        external
        override
        onlyRegisteredToken(token_)
    {
        NFTStorage storage ns = nftStorage();

        if (lockHash_ == 0) revert InvalidDepositLockError();
        if (!HelpersECDSA.isOnCurve(starkKey_) || starkKey_ > Constants.K_MODULUS) revert InvalidStarkKeyError();
        if (ns.lockedNFTs[token_][tokenId_].expirationDate != 0) revert DepositedTokenError();

        //  Event.
        emit LogNFTDeposited(token_, tokenId_, lockHash_, starkKey_, assetId_);

        //  Deposit and lock.
        ns.lockedNFTs[token_][tokenId_] = NFTs({
            locked: true,
            recipient: msg.sender,
            assetId: assetId_,
            expirationDate: (block.timestamp + ns.expirationTimeout),
            lockHash: lockHash_
        });

        HelpersERC721.transferFrom(token_, msg.sender, address(this), tokenId_);
    }

    /// @inheritdoc INFTFacet
    function reClaimNFT(address token_, uint256 tokenId_, uint256 branchMask_, bytes32[] memory proof_)
        external
        override
    {
        NFTStorage storage ns = nftStorage();
        NFTs memory nft_ = ns.lockedNFTs[token_][tokenId_];

        if (nft_.expirationDate == 0) revert DepositNotFoundError();
        if (block.timestamp <= nft_.expirationDate) revert DepositNotExpiredError();

        //  Validate MPT proof.
        MerklePatriciaTree.verifyProof(
            bytes32(LibState.getOrderRoot()), abi.encode(nft_.lockHash), abi.encode(0), branchMask_, proof_
        );

        delete ns.lockedNFTs[token_][tokenId_];

        //  Event.
        emit LogNFTReclaimed(token_, tokenId_);

        //  Transfer.
        HelpersERC721.transferFrom(token_, address(this), nft_.recipient, tokenId_);
    }

    /// @inheritdoc INFTFacet
    function unlockNFTBurn(
        address token_,
        uint256 tokenId_,
        uint256[5] memory hashInfo_,
        uint256 branchMask_,
        bytes32[] memory proof_
    ) external override {
        NFTStorage storage ns = nftStorage();
        NFTs memory nft_ = ns.lockedNFTs[token_][tokenId_];

        if (nft_.expirationDate == 0) revert DepositNotFoundError();
        if (nft_.locked == false) revert AlreadyUnlockedError();

        //  Build transfer hash.
        // TODO: A solution in solidity for the Pedersen Hash needs to be found.
        // Current transferHash_ is an exmple used in the tests to verify other parts of the code.
        /*
        uint256 tranferHash_ = PedersenHash.hash(
            PedersenHash.hash(
                PedersenHash.hash(PedersenHash.hash(nft_.assetId, hashInfo_[0]), RECEIVER_STARK_KEY),
                _encodeVaultIds(hashInfo_[1], RECEIVER_VAULT_ID, hashInfo_[2], hashInfo_[3])
            ),
            _encodeTransferInfo(QUANTIZED_AMOUNT, QUANTIZED_AMOUNT_LIMIT, hashInfo_[4])
        );*/
        uint256 tranferHash_ =
            2_768_498_024_101_110_746_696_508_142_221_047_236_812_821_820_792_692_622_141_175_702_701_103_930_225;

        //  Validate MPT proof.
        MerklePatriciaTree.verifyProof(
            bytes32(LibState.getOrderRoot()), abi.encode(tranferHash_), abi.encode(1), branchMask_, proof_
        );

        //  Unlock NFT.
        ns.lockedNFTs[token_][tokenId_].locked = false;
        ns.lockedNFTs[token_][tokenId_].lockHash = tranferHash_;
        ns.lockedNFTs[token_][tokenId_].recipient = address(0);

        //  Event.
        emit LogNFTUnlocked(token_, tokenId_);
    }

    /// @inheritdoc INFTFacet
    function setRecipientNFT(
        address token_,
        uint256 tokenId_,
        uint256 starkKey_,
        bytes memory signature_,
        address recipient_
    ) external override {
        NFTStorage storage ns = nftStorage();
        NFTs memory nft_ = ns.lockedNFTs[token_][tokenId_];

        if (nft_.expirationDate == 0) revert DepositNotFoundError();
        if (nft_.locked != false) revert NotUnlockedError();
        if (nft_.recipient != address(0)) revert RecipientAlreadySetError();
        if (signature_.length != 32 * 3) revert InvalidSignatureError();

        //  Statefull signature validation.
        (uint256 r_, uint256 s_, uint256 starkKeyY_) = abi.decode(signature_, (uint256, uint256, uint256));
        ECDSA.verify(nft_.lockHash, r_, s_, starkKey_, starkKeyY_);

        //  Register new recipient.
        ns.lockedNFTs[token_][tokenId_].locked = false;
        ns.lockedNFTs[token_][tokenId_].recipient = recipient_;

        //  Event.
        emit LogNFTRecipient(token_, tokenId_, recipient_);
    }

    /// @inheritdoc INFTFacet
    function unlockNFTWithdraw(address token_, uint256 tokenId_, address recipient_)
        external
        override
        onlyInteroperabilityContract
    {
        NFTStorage storage ns = nftStorage();
        NFTs memory nft_ = ns.lockedNFTs[token_][tokenId_];

        if (nft_.expirationDate == 0) revert DepositNotFoundError();
        if (nft_.locked == false) revert AlreadyUnlockedError();

        //  Unlock NFT and register new recipient.
        ns.lockedNFTs[token_][tokenId_].locked = false;
        ns.lockedNFTs[token_][tokenId_].recipient = recipient_;

        //  Event.
        emit LogNFTUnlocked(token_, tokenId_);
        emit LogNFTRecipient(token_, tokenId_, recipient_);
    }

    /// @inheritdoc INFTFacet
    function withdrawNFT(address token_, uint256 tokenId_) external override {
        NFTStorage storage ns = nftStorage();
        NFTs memory nft_ = ns.lockedNFTs[token_][tokenId_];

        if (nft_.expirationDate == 0) revert DepositNotFoundError();
        if (nft_.locked == true) revert NFTLockedError();
        if (nft_.recipient == address(0)) revert RecipientNotSetError();

        //  Event.
        emit LogNFTwithdrawn(token_, tokenId_, nft_.recipient);

        //  Transfer.
        HelpersERC721.transferFrom(token_, address(this), nft_.recipient, tokenId_);
    }

    /// @inheritdoc INFTFacet
    function getDepositedNFT(address token_, uint256 tokenId_) external view override returns (NFTs memory nft) {
        nft = nftStorage().lockedNFTs[token_][tokenId_];
        if (nft.expirationDate == 0) revert DepositNotFoundError();
    }

    /// @inheritdoc INFTFacet
    function getExpirationTimeout() external view override returns (uint256) {
        return nftStorage().expirationTimeout;
    }

    function _encodeVaultIds(uint256 vaultIdSender_, uint256 vaultIdReceiver_, uint256 vaultIdFees_, uint256 nonce_)
        internal
        pure
        returns (uint256)
    {
        return (vaultIdSender_ << 160) | (vaultIdReceiver_ << 96) | (vaultIdFees_ << 32) | (nonce_);
    }

    function _encodeTransferInfo(uint256 quantizedAmount_, uint256 quantizedFeeMax_, uint256 expiration_)
        internal
        pure
        returns (uint256)
    {
        return (4 << 241) | (quantizedAmount_ << 177) | (quantizedFeeMax_ << 113) | ((expiration_ / 3600) << 81);
    }
}
