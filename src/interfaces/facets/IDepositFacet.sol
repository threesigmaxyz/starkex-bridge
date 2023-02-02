// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { CompactMerkleProof } from "src/dependencies/mpt/compact/CompactMerkleProof.sol";

interface IDepositFacet {
    struct Deposit {
        address receiver;
        uint256 starkKey;
        address token;
        uint256 amount;
        uint256 expirationDate;
    }

    struct DepositStorage {
        mapping(uint256 => Deposit) deposits;
        mapping(address => uint256) pendingDeposits;
        uint256 depositExpirationTimeout;
    }

    /**
     * @notice Emits a deposit was locked so the backend can process it.
     * @param lockHash The hash of the transfer to the user.
     * @param starkKey The public starkKey of the user.
     * @param token The address of the token or native currency.
     * @param amount The amount of funds.
     */
    event LogLockDeposit(uint256 indexed lockHash, uint256 indexed starkKey, address indexed token, uint256 amount);

    /**
     * @notice Emits a deposit was claimed by the operator.
     * @param lockHash The hash of the transfer to the user.
     * @param recipient The recipient of the deposit.
     */
    event LogClaimDeposit(uint256 indexed lockHash, address indexed recipient);

    /**
     * @notice Emits a deposit was reclaimed by the operator.
     * @param lockHash The hash of the transfer to the user.
     */
    event LogReclaimDeposit(uint256 indexed lockHash);

    /**
     * @notice Emits the new deposit expiration timeout.
     * @param timeout The new timeout.
     */
    event LogSetDepositExpirationTimeout(uint256 indexed timeout);

    /// @dev Stateless errors.
    error InvalidDepositLockError();
    error InvalidStarkKeyError();
    error ZeroAmountError();
    error ZeroAddressRecipientError();
    /// @dev Statefull errors.
    error DepositPendingError();
    error DepositNotFoundError();
    error DepositNotExpiredError();

    /**
     * @notice Sets the deposit expiration timeout.
     * @dev Only callable by the owner.
     * @param timeout_ The expiration time.
     */
    function setDepositExpirationTimeout(uint256 timeout_) external;

    /**
     * @notice Locks a deposit until the hash of the transfer is included in the Merkle Tree.
     * @param starkKey_ The public starkKey of the user.
     * @param token_ The address of the token or native currency.
     * @param amount_ The amount of funds.
     * @param lockHash_ The hash of the transfer to the user.
     */
    function lockDeposit(uint256 starkKey_, address token_, uint256 amount_, uint256 lockHash_) external;

    /**
     * @notice Locks a native deposit until the hash of the transfer is included in the Merkle Tree.
     * @param starkKey_ The public starkKey of the user.
     * @param lockHash_ The hash of the transfer to the user.
     */
    function lockNativeDeposit(uint256 starkKey_, uint256 lockHash_) external payable;

    /**
     * @notice Claim a deposit if the hash of the transfer was included in the Merkle Tree.
     * @param lockHash_ The hash of the transfer to the user.
     * @param branchMask_ Bits defining the path to the correct node.
     * @param proof_ The Merkle proof proving that the transfer is in the Merkle Tree.
     * @param recipient_ The recipient of the deposit.
     */
    function claimDeposit(uint256 lockHash_, uint256 branchMask_, bytes32[] memory proof_, address recipient_)
        external;

    /**
     * @notice Claim multiple deposits if the hashes of the transfers were included in the Merkle Tree.
     * @param lockHashes_ The hashes of the transfers.
     * @param proof_ The Merkle proof proving that the transfers are in the Merkle Tree.
     * @param recipient_ The recipient of the deposits.
     */
    function claimDeposits(CompactMerkleProof.Item[] memory lockHashes_, bytes[] memory proof_, address recipient_)
        external;

    /**
     * @notice Reclaims a deposit if enough time has passed and the request failed.
     * @param lockHash_ The hash of the transfer to the user.
     */
    function reclaimDeposit(uint256 lockHash_) external;

    /**
     * @notice Gets a deposit from its lockHash and reverts if not found.
     * @param lockHash_ The hash of the transfer to the user.
     * @return Returns the deposit if found.
     */
    function getDeposit(uint256 lockHash_) external view returns (Deposit memory);

    /**
     * @notice Gets the total amount of pending deposits for a token.
     * @param token_ The address of the ERC20 token or native currency.
     * @return Returns the amount of pending deposits.
     */
    function getPendingDeposits(address token_) external view returns (uint256);

    /**
     * @notice Gets the deposit expiration timeout.
     * @return Returns the timeout value.
     */
    function getDepositExpirationTimeout() external view returns (uint256);
}
