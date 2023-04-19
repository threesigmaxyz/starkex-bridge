// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILzReceptor {
    /**
     * @notice Emitted when the bridge address is set.
     * @param bridge The bridge address.
     */
    event LogSetBridge(address indexed bridge);

    /**
     * @notice Emitted when the liquidity bridge address is set.
     * @param liquidityBridge The liquidity bridge address.
     */
    event LogSetLiquidityBridge(address indexed liquidityBridge);

    /**
     * @notice Emitted when a deposit is made to starkEx.
     * @param srcChainId The chain Id of the token.
     * @param starkKey The public STARK key.
     * @param vaultId The stakers off-chain account.
     * @param token Address of the token.
     * @param amount Amount to be deposited.
     */
    event LogMintDepositStarkEx(
        uint16 srcChainId, uint256 indexed starkKey, uint256 indexed vaultId, address indexed token, uint256 amount
    );

    /// @notice Emitted when the interoperability role in the bridge is accepted.
    event LogBridgeRoleAccepted();

    error ZeroBridgeAddressError();
    error ZeroLzEndpointAddressError();

    /// @notice Accepts the pending bridge role.
    function acceptBridgeRole() external;

    /// @notice Set the address of the liquidity bridge contract.
    /// @param liquidityBridge_ Address of the contract.
    function setLiquidityBridge(address liquidityBridge_) external;
}
