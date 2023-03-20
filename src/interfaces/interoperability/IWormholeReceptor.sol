// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWormholeReceptor {
    /**
     * @notice Emitted when the bridge address is set.
     * @param bridge The bridge address.
     */
    event LogSetBridge(address indexed bridge);

    /**
     * @notice Emitted when an outdated root is received (lz messages sent in the wrong order).
     * @param orderRoot The order root.
     * @param nonce The nonce of the message.
     */
    event LogOutdatedRootReceived(uint256 indexed orderRoot, uint64 indexed nonce);

    /**
     * @notice Emitted when the order root of the bridge is updated.
     * @param orderRoot The order root.
     */
    event LogOrderRootUpdate(uint256 indexed orderRoot);

    /**
     * @notice Emitted when an order root is received.
     * @param orderRoot The order root.
     */
    event LogRootReceived(uint256 indexed orderRoot);

    /// @notice Emitted when the interoperability role in the bridge is accepted.
    event LogBridgeRoleAccepted();

    error ZeroBridgeAddressError();
    error ZeroRelayerAddressError();
    error ZeroWormholeAddressError();
    error InvalidCallerError();
    error VerificationFailError(string reason_);
    error InvalidEmitterError();
    error AlreadyProcessedError();
    error NotIntendedRecipientError();

    /// @notice Accepts the pending bridge role.
    function acceptBridgeRole() external;

    /**
     * @notice The owner sets the root of the order tree.
     *         This adds another layer of security, stopping layerZero from sending any message.
     */
    function setOrderRoot() external;

    /**
     * @notice Receives the root update.
     * @param whMessages_ Contains the root and the intended recipient.
     */
    function receiveWormholeMessages(bytes[] memory whMessages_, bytes[] memory) external payable;
}
