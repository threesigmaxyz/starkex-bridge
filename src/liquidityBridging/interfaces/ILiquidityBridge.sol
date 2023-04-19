// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILiquidityBridge {
    /**
     * @notice Emitted when the address of the starkEx contract is set.
     * @param starkEx The address of the starkEx contract.
     */
    event LogSetStarkExAddress(address indexed starkEx);

    /**
     * @notice Emitted when a deposit is made to starkEx.
     * @param starkKey The public STARK key.
     * @param vaultId The stakers off-chain account.
     * @param assetType Identifier of the deposited asset.
     * @param amount Amount to be deposited.
     */
    event LogDepositStarkEx(
        uint256 indexed starkKey, uint256 indexed vaultId, uint256 indexed assetType, uint256 amount
    );

    /**
     * @notice Emitted when a new wrapped token is added to the contract.
     * @param srcChainId The chain Id of the token to wrap.
     * @param token The address of the token.
     * @param wrappedToken The address of the wrapped token.
     */
    event LogAddWrappedToken(uint16 indexed srcChainId, address indexed token, address indexed wrappedToken);

    /**
     * @notice Emitted when a token is registed in StarkEx.
     * @param assetType Identifier of the registed asset.
     * @param assetInfo Info of the registed asset.
     * @param quantum The StarkEx asset quantum.
     */
    event LogTokenRegistedStarkEx(uint256 indexed assetType, bytes indexed assetInfo, uint256 quantum);

    error ZeroStarkExAddressError();
    error ZeroReceptorAddressError();
    error ZeroTokenAddressError();
    error NotReceptorError();
    error ZeroWrappedTokenError();

    /**
     * @notice Mint wrapped tokens and deposit in StarkEx.
     * @param srcChainId_ The source chain Id of the token to wrap.
     * @param starkKey_ The public STARK key.
     * @param vaultId_ The stakers off-chain account.
     * @param token_ The address of the token to wrap.
     * @param amount_ Amount to be deposited.
     */
    function mintAndDepositStarkEx(
        uint16 srcChainId_,
        uint256 starkKey_,
        uint256 vaultId_,
        address token_,
        uint256 amount_
    ) external;

    /**
     * @notice Deploy wrapped token and register in StarkEx.
     * @param srcChainId_ The source chain Id of the token to wrap.
     * @param token_ The address of the token to wrap.
     * @param quantum_ The StarkEx asset quantum.
     */
    function deployAndRegisterWrappedToken(uint16 srcChainId_, address token_, uint256 quantum_) external;

    /**
     * @notice Used t find the address of a wrapped token.
     * @param srcChainId_ The source chain Id of the token.
     * @param token_ The address of the token that was wrapped.
     * @return The address of the wrapped token.
     */
    function getWrappedTokenAddress(uint16 srcChainId_, address token_) external view returns (address);

    /**
     * @notice Used to find the address of the factory.
     * @return The address of the wrapped token factory.
     */
    function getFactoryAddress() external view returns (address);
}
