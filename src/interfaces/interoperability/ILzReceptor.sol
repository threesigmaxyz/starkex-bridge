// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILzReceptor {

    /**
     * @notice Emitted when an outdated root is received (lz messages sent in the wrong order).
     * @param orderRoot The order root.
     * @param nonce The nonce of the message.
     */
    event LogOutdatedRootReceived(uint256 orderRoot, uint64 nonce);

    /**
     * @notice Emitted when the order root of the bridge is updated.
     * @param orderRoot The order root.
     */
    event LogOrderRootUpdate(uint256 orderRoot);

    /// @notice Emitted when the interoperability role in the bridge is accepted.
    event LogBridgeRoleAccepted();

    /**
     * @notice Emitted when the bridge contract is set.
     * @param bridge The address of the bridge.
     */
    event LogBridgeSet(address bridge);

    error ZeroBridgeAddressError();
    error ZeroLzEndpointAddressError();

    /// @notice Accepts the pending bridge role.
    function acceptBridgeRole() external;
}