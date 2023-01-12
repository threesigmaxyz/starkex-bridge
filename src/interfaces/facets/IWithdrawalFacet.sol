// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWithdrawalFacet {
    struct Withdrawal {
        address recipient;
        uint256 starkKey;
        address token;
        uint256 amount;
        uint256 expirationDate;
    }

    struct WithdrawalStorage {
        mapping(uint256 => Withdrawal) withdrawals;
        mapping(address => uint256) pendingWithdrawals;
        uint256 withdrawalExpirationTimeout;
    }

    /**
     * @notice Emitted when a user request is made to the off chain application.
     * that consequently locks funds in this contract.
     * @dev The funds are locked temporarily in this contract.
     * @param lockHash The lock hash to be signed that transfers funds to the app.
     * @param starkKey The public STARK key that must sign the lock hash.
     * @param token The asset to be locked.
     * @param amount The amount of funds to be locked.
     */
    event LogLockWithdrawal(
        uint256 indexed lockHash, uint256 indexed starkKey, address indexed token, uint256 amount, address recipient
    );

    /**
     * @notice Emitted when a withdraw is signed and completed by a user
     * @dev The funds are transfered to the user wallet and the lock is cleared allowing
     * new withdraws.
     * @param lockHash The lock hash to be signed that transfers funds to the app.
     * @param signature The signature of the lock hash.
     * @param recipient The address that will receive the funds.
     */
    event LogClaimWithdrawal(uint256 indexed lockHash, bytes indexed signature, address indexed recipient);

    /**
     * @notice Emitted when a user withdraw request expires and a request is made to unlock funds.
     * @dev Fallback Function.
     * @param lockHash The lock hash to be signed that transfers funds to the app.
     * @param recipient The recipient of the funds.
     */
    event LogReclaimWithdrawal(uint256 indexed lockHash, address indexed recipient);

    /**
     * @notice Emitted when the withdrawal expiration timeout is set.
     * @param timeout The timeout.
     */
    event LogSetWithdrawalExpirationTimeout(uint256 indexed timeout);

    error InvalidLockHashError();
    error ZeroAddressRecipientError();
    error InvalidStarkKeyError();
    error ZeroAmountError();
    error InvalidSignatureError();
    error WithdrawalAlreadyExistsError();
    error WithdrawalNotFoundError();
    error WithdrawalNotExpiredError();

    /**
     * @notice Sets the withdrawal expiration timeout.
     * @dev only callable by the owner.
     * @param timeout_ The timeout.
     */
    function setWithdrawalExpirationTimeout(uint256 timeout_) external;

    /**
     * @notice Lock native funds to be withdrawn
     * @dev Verifies if there are enough funds to lock and then lock funds.
     * @param starkKey_ The public STARK key that must sign the lock hash.
     * @param lockHash_ The lock hash to be signed that transfers funds to the app.
     * @param recipient_ The recipient of the withdrawal.
     */
    function lockNativeWithdrawal(uint256 starkKey_, uint256 lockHash_, address recipient_) external payable;

    /**
     * @notice Lock funds to be withdrawn
     * @dev Verifies if there are enough funds to lock and then lock funds.
     * @param starkKey_ The public STARK key that must sign the lock hash.
     * @param token_ Asset address to be withdrawn.
     * @param amount_ Amount to be withdrawn.
     * @param lockHash_ The lock hash to be signed that transfers funds to the app.
     * @param recipient_ The recipient of the withdrawal.
     */
    function lockWithdrawal(uint256 starkKey_, address token_, uint256 amount_, uint256 lockHash_, address recipient_)
        external;

    /**
     * @notice Withdraw funds that were previously locked.
     * @dev First verifies signature, then clears data and then withdraws funds.
     * @param lockHash_ The lock hash to be signed that transfers funds to the app.
     * @param signature_ The signature that signed the lockHash.
     */
    function claimWithdrawal(uint256 lockHash_, bytes memory signature_) external;

    /**
     * @notice The operator can unlock funds if lock expires.
     * @dev Verify if lock exists and expired and deletes it returning the funds to the recipient.
     * @param lockHash_ The lock hash to be signed that transfers funds to the app.
     * @param recipient_ The recepient of the funds.
     */
    function reclaimWithdrawal(uint256 lockHash_, address recipient_) external;

    /**
     * @notice Gets the withdrawal from the lockHash_.
     * @dev reverts if not found.
     * @param lockHash_ The lock hash to be signed that transfers funds to the app.
     * @return withdrawal_ The withdrawal.
     */
    function getWithdrawal(uint256 lockHash_) external view returns (Withdrawal memory withdrawal_);

    /**
     * @notice Gets the total pending withdrawal amount for a token.
     * @param token_ The address of the token or native currency.
     * @return pending_ The amount.
     */
    function getPendingWithdrawals(address token_) external view returns (uint256 pending_);

    /**
     * @notice Gets the withdrawal expiration timeout.
     * @return Returns the timeout value.
     */
    function getWithdrawalExpirationTimeout() external view returns (uint256);
}
