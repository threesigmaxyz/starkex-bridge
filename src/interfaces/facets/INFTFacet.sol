// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INFTFacet {
    struct NFTStorage {
        mapping(address => mapping(uint256 => NFTs)) lockedNFTs;
        uint256 expirationTimeout;
    }

    struct NFTs {
        bool locked;
        address recipient;
        uint256 assetId;
        uint256 expirationDate;
        uint256 lockHash;
    }

    /**
     * @notice Emits when a deposit of a NFT was locked so the backend can process it.
     * @param token The address of the token.
     * @param tokenId The id of the token.
     * @param lockHash The hash of the transfer to the user.
     * @param starkKey The public starkKey of the user.
     * @param assetId The Id of the asset that will be minted in StarkEx.
     */
    event LogNFTDeposited(
        address indexed token, uint256 indexed tokenId, uint256 indexed lockHash, uint256 starkKey, uint256 assetId
    );

    /**
     * @notice Emits when a deposit is reclaimed by the user.
     * @param token The address of the token.
     * @param tokenId The id of the token.
     */
    event LogNFTReclaimed(address indexed token, uint256 indexed tokenId);

    /**
     * @notice Emits the new expiration timeout.
     * @param timeout The new timeout.
     */
    event LogSetExpirationTimeout(uint256 indexed timeout);

    /**
     * @notice Emits when a NFT is unlocked.
     * @param token The address of the token.
     * @param tokenId The id of the token.
     */
    event LogNFTUnlocked(address indexed token, uint256 indexed tokenId);

    /**
     * @notice Emits when a NFT recipient is set.
     * @param token The address of the token.
     * @param tokenId The id of the token.
     * @param recipient The address that receives the NFT.
     */
    event LogNFTRecipient(address indexed token, uint256 indexed tokenId, address indexed recipient);

    /**
     * @notice Emits when a NFT is withdrawn.
     * @param token The address of the token.
     * @param tokenId The id of the token.
     * @param recipient The address that receives the NFT.
     */
    event LogNFTwithdrawn(address indexed token, uint256 indexed tokenId, address indexed recipient);

    error InvalidStarkKeyError();
    error DepositedTokenError();
    error DepositNotFoundError();
    error DepositNotExpiredError();
    error InvalidDepositLockError();
    error NFTLockedError();
    error AlreadyUnlockedError();
    error RecipientAlreadySetError();
    error NotUnlockedError();
    error InvalidSignatureError();
    error RecipientNotSetError();

    /**
     * @notice Sets the expiration timeout.
     * @dev Only callable by the owner.
     * @param timeout_ The expiration time.
     */
    function setExpirationTimeout(uint256 timeout_) external;

    /**
     * @notice Allows for a user to deposit a NFT.
     * @param starkKey_ The public starkKey of the user.
     * @param token_ The address of the token.
     * @param tokenId_ The token Id.
     * @param lockHash_ The hash of the transfer to the user.
     * @param assetId_ The Id of the asset that will be minted in StarkEx.
     */
    function depositNFT(uint256 starkKey_, address token_, uint256 tokenId_, uint256 lockHash_, uint256 assetId_)
        external;

    /**
     * @notice Reclaims a deposit if enough time has passed and the request failed.
     * @param token_ The address of the token.
     * @param tokenId_ The token Id.
     * @param branchMask_ Bits defining the path to the correct node.
     * @param proof_ The Merkle proof proving that the transfer isn't in the Merkle Tree.
     */
    function reClaimNFT(address token_, uint256 tokenId_, uint256 branchMask_, bytes32[] memory proof_) external;

    /**
     * @notice Unlocks the NFT to be withdrawn when the asset in the app is sent to a burn vault.
     * @dev hashInfo_: AssetId Fees, Receiver Stark Key, VaultId Sender, VaultId Fees, Nonce, Expiration;
     * @param token_ The address of the token.
     * @param tokenId_ The token Id.
     * @param hashInfo_ The info necessary to complete the hash of the transfer.
     * @param branchMask_ Bits defining the path to the correct node.
     * @param proof_ The Merkle proof proving that the transfer is in the Merkle Tree.
     */
    function unlockNFTBurn(
        address token_,
        uint256 tokenId_,
        uint256[5] memory hashInfo_,
        uint256 branchMask_,
        bytes32[] memory proof_
    ) external;

    /**
     * @notice Used to set a recipient for an NFT that has been unlocked.
     * @notice This only works if it was unlocked by sending the asset to a burn vault.
     * @param token_ The address of the token.
     * @param tokenId_ The token Id.
     * @param starkKey_ The public STARK key that must sign the lock hash.
     * @param signature_ The signature that signed the lockHash.
     * @param recipient_ The address that will receive the NFT.
     */
    function setRecipientNFT(
        address token_,
        uint256 tokenId_,
        uint256 starkKey_,
        bytes memory signature_,
        address recipient_
    ) external;

    /**
     * @notice Unlocks the NFT to be withdrawn when the asset in the app is withdrawn regularly.
     * @dev Can only be acessed by interoperability contract since the unlock order comes from there.
     * @param token_ The address of the token.
     * @param tokenId_ The token Id.
     * @param recipient_ The address that will receive the NFT.
     */
    function unlockNFTWithdraw(address token_, uint256 tokenId_, address recipient_) external;

    /**
     * @notice Withdraws the NFT if unlocked to its recipient.
     * @param token_ The address of the token.
     * @param tokenId_ The token Id.
     */
    function withdrawNFT(address token_, uint256 tokenId_) external;

    /**
     * @notice Gets a NFT from its lockHash and reverts if not found.
     * @param token_ The address of the token.
     * @param tokenId_ The token Id.
     * @return nft Returns the NFT if found.
     */
    function getDepositedNFT(address token_, uint256 tokenId_) external view returns (NFTs memory nft);

    /**
     * @notice Gets the expiration timeout.
     * @return Returns the timeout value.
     */
    function getExpirationTimeout() external view returns (uint256);
}
