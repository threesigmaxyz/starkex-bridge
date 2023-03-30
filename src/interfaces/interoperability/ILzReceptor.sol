// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILzReceptor {
    /**
     * @notice Emitted when an order root is received.
     * @param payload The payload.
     */
    event LogRootReceived(bytes indexed payload);

    /**
     * @notice Emitted when the address of the multi bridge receiver is set.
     * @param multiBridgeReceiver The new address.
     */
    event LogSetMultiBridgeAddress(address indexed multiBridgeReceiver);

    /// @notice Emitted when the interoperability role in the bridge is accepted.
    event LogBridgeRoleAccepted();

    error ZeroLzEndpointAddressError();
    error ZeroMultiBridgeAddressError();

    /**
     * @notice Set the multiBridgeReceptor address.
     * @param multiBridgeReceiver_ The new address.
     */
    function setMultiBridgeAddress(address multiBridgeReceiver_) external;

    /**
     * @notice Get the multiBridgeReceptor address.
     * @return The address.
     */
    function getMultiBridgeAddress() external view returns (address);
}
