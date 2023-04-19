// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakerFacet {
    struct Staker {
        address staker;
        uint256 starkKey;
        uint256 vaultId;
        address token;
        uint256 amount;
        uint256 amountLocked;
    }

    struct StakerStorage {
        mapping(bytes => Staker) stakers;
        address transmitter;
    }

    /**
     * @notice Emitted when the transmitter address is set.
     * @param transmitter The address of the transmitter.
     */
    event LogSetTransmitter(address indexed transmitter);

    /**
     * @notice Emitted when a staker sends funds for starkEx when registering.
     * @param payload Payload sent in message.
     * @param staker Address of the staker.
     */
    event LogStakerMessageSent(bytes indexed payload, address indexed staker);

    error ZeroAddressStakerError();
    error NotEnoughtFeeError();
    error InvalidStarkKeyError();
    error ZeroAmountError();
    error StakerNotFoundError();

    /**
     * @notice Register a staker using native funds.
     * @dev Verifies if there are enough funds to create a staker and then keeps half for liquidity
     *    and the other half is sent to starkexpress for liquidity there.
     * @param staker_ The address of the staker.
     * @param starkKey_ The public STARK key.
     * @param vaultId_ The stakers off-chain account.
     * @param amount_ The amount of token ro stake.
     */
    function registerNativeStaker(address payable staker_, uint256 starkKey_, uint256 vaultId_, uint256 amount_)
        external
        payable;

    /**
     * @notice Register a staker.
     *  Verifies if there are enough funds to create a staker and then keeps half for liquidity
     *    and the other half is sent to starkexpress for liquidity there.
     * @param staker_ The address of the staker.
     * @param starkKey_ The public STARK key.
     * @param vaultId_ The stakers off-chain account.
     * @param token_ Asset address to be staked.
     * @param amount_ Amount to be staked.
     */
    function registerStaker(
        address payable staker_,
        uint256 starkKey_,
        uint256 vaultId_,
        address token_,
        uint256 amount_
    ) external payable;

    /**
     * @notice Sets the transmitter for the stake;
     * @param transmitter_ The address of the transmitter.
     */
    function setTransmitter(address transmitter_) external;

    /**
     * @notice Gets the transmitter for the stake;
     * @return The address of the transmitter.
     */
    function getTransmitter() external view returns (address);

    /**
     * @notice Gets the staker info.
     * @dev reverts if not found.
     * @param addr_ The address of the staker.
     * @param token_ Address of the token staked.
     * @return staker_ The staker.
     */
    function getStakerInfo(address addr_, address token_) external view returns (Staker memory staker_);
}
