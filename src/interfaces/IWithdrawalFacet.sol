// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWithdrawalFacet {

    /// @notice TODO
    struct Withdrawal {
        uint256 starkKey;
        address token;
        uint256 amount;
        uint256 expirationDate;
    }

    struct WithdrawalStorage {
		mapping(uint256 => Withdrawal) withdrawals;
		mapping(address => uint256) pendingWithdrawals;
	}

    /**
     * @notice Emitted when a user request is made to the off chain application.
     * that consequently locks funds in this contract.
     * @dev The funds are locked temporarily in this contract.
     * @param lockHash The lock hash to be signed.
     * @param starkKey The STARK key that must sign the lock hash.
     * @param token The asset to be locked.
     * @param amount The amount of funds to be locked.
     */
    event LogLockWithdrawal(uint256 indexed lockHash, uint256 indexed starkKey, address indexed token, uint256 amount);

    /**
     * @notice Emitted when a withdraw is signed and completed by a user
     * @dev The funds are transfered to the user wallet and the lock is cleared allowing
     * new withdraws.
     * @param lockHash TODO
     * @param recipient The address that will receive the funds
     */
    event LogClaimWithdrawal(uint256 indexed lockHash, address indexed recipient);

    /**
     * @notice Emitted when a user withdraw request expires and a request is made to unlock funds
     * @dev Fallback Function
     * @param lockHash TODO
     * @param recipient TODO
     */
    event LogReclaimWithdrawal(uint256 indexed lockHash, address indexed recipient);

    error InvalidLockHashError();
    error InvalidRecipientError();
    error InvalidStarkKeyError();
    error ZeroAmountError();
    error InvalidSignatureError();
    error WithdrawalAlreadyExistsError();
    error WithdrawalNotFoundError();
    error WithdrawalNotExpiredError();

    /**
     * @notice Lock funds to be withdrawn
     * @dev Verify if there are enough funds to lock and then lock funds
     * @param starkKey_ TODO
     * @param token_ Asset address to be withdrawn
     * @param amount_ Amount to be withdrawn
     * @param lockHash_ TODO
     */
    function lockWithdrawal(
        uint256 starkKey_,
        address token_,
        uint256 amount_,
        uint256 lockHash_
    ) external;

    /// @notice Withdraw funds that were previously locked
    /// @dev First verifies signature, then clears data and then withdraws funds
    /// @param lockHash_ TODO
    /// @param signature_ TODO
    /// @param recipient_ TODO
    function claimWithdrawal(
        uint256 lockHash_,
        bytes memory signature_,
        address recipient_
    ) external;

    /// @notice Unlock funds if lock expires
    /// @dev Verify if lock exists and expired and deletes it returning funds to the available funds.
    /// @param lockHash_ TODO
    /// @param recipient_ TODO
    function reclaimWithdrawal(uint256 lockHash_, address recipient_) external;

    /// @notice TODO
    /// @param hashId_ TODO
    /// @return withdrawal_ TODO
    function getWithdrawal(uint256 hashId_) external view returns (Withdrawal memory withdrawal_);

    /// @notice TODO
    /// @param token_ TODO
    /// @return pending_ TODO
    function getPendingWithdrawals(address token_) external view returns (uint256 pending_);
}