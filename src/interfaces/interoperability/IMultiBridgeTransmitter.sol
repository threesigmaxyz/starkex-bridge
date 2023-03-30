// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMultiBridgeTransmitter {
    /**
     * @notice Emitted when the address of the starkEx contract is set.
     * @param starkEx The address of the starkEx contract.
     */
    event LogSetStarkExAddress(address indexed starkEx);

    /**
     * @notice Emitted when an individual bridge succeds to transmit the payload.
     * @param bridgeTransmitter The address of the brige that failed to transmit.
     * @param dstChainId The destination chain identifier.
     * @param payload The payload of the message.
     */
    event LogTransmitSuccess(
        address indexed bridgeTransmitter, uint16 indexed dstChainId, uint256 sequenceNumber, bytes indexed payload
    );

    /**
     * @notice Emitted when an individual bridge fails to transmit the payload.
     * @param bridgeTransmitter The address of the brige that failed to transmit.
     * @param dstChainId The destination chain identifier.
     * @param payload The payload of the message.
     */
    event LogTransmitFailed(
        address indexed bridgeTransmitter, uint16 indexed dstChainId, uint256 sequenceNumber, bytes indexed payload
    );

    /**
     * @notice Emitted when all bridges have tried to send a message.
     * @param dstChainId The destination chain identifier.
     * @param sequenceNumber The sequence number of the message sent.
     * @param payload The payload of the message.
     */
    event LogMultiBridgeMsgSend(uint16 indexed dstChainId, uint256 indexed sequenceNumber, bytes indexed payload);

    /**
     * @notice Emitted when an individual bridge succeds to transmit the payload to all the chain.
     * @param bridgeTransmitter The address of the brige that failed to transmit.
     * @param dstChainId The destinations chain identifiers.
     * @param payload The payload of the message.
     */
    event LogBatchTransmitSuccess(
        address indexed bridgeTransmitter, uint16[] indexed dstChainId, uint256 sequenceNumber, bytes indexed payload
    );

    /**
     * @notice Emitted when an individual bridge fails to transmit the payload to all the chain.
     * @param bridgeTransmitter The address of the brige that failed to transmit.
     * @param dstChainId The destinations chain identifiers.
     * @param payload The payload of the message.
     */
    event LogBatchTransmitFailed(
        address indexed bridgeTransmitter, uint16[] indexed dstChainId, uint256 sequenceNumber, bytes indexed payload
    );

    /**
     * @notice Emitted when all bridges have tried to send a message to all chains.
     * @param dstChainId The destination chain identifier.
     * @param sequenceNumber The sequence number of the message sent.
     * @param payload The payload of the message.
     */
    event LogMultiBridgeMsgBatchSend(
        uint16[] indexed dstChainId, uint256 indexed sequenceNumber, bytes indexed payload
    );

    /**
     * @notice Emitted when a new bridge is added to the multi bridge contract.
     * @param newBridge Address of the new bridge transmitter.
     */
    event LogNewBridgeAdded(address indexed newBridge);

    /**
     * @notice Emitted when a bridge is removed from the multi bridge contract.
     * @param removeBridge Address of the bridge transmitter to remove.
     */
    event LogBridgeRemoved(address indexed removeBridge);

    error ZeroStarkExAddressError();
    error BridgeAlreadyAddedError();
    error BridgeNotInListError();
    error RefundError();
    error StaleUpdateError(uint16 chainId, uint256 sequenceNumber);

    /**
     * @notice Gets the starkEx order root to send to the LzReceptor in the sideChains.
     * @return payload_ The payload of the message.
     */
    function getPayload() external view returns (bytes memory payload_);

    /**
     * @notice Updates the order root of the interoperability contract in the sideChain by calling all available bridge tranmitters.
     * @param dstChainId_ The destination chain identifier.
     * @param refundAddress_ The refund address of the unused ether sent.
     */
    function send(uint16 dstChainId_, address payable refundAddress_) external payable;

    /**
     * @notice Updates the order root of the interoperability contract in the selected sideChains by calling all available bridge tranmitters.
     * @param dstChainIds_ The id of the destination chains.
     * @param refundAddress_ The refund address of the unused ether sent.
     */
    function sendBatch(uint16[] calldata dstChainIds_, address payable refundAddress_) external payable;

    /**
     * @notice Calculates the total fee for transmitting on all bridges.
     * @param dstChainId_ The id of the destination chain.
     * @return Total of fees.
     */
    function calcTotalFee(uint16 dstChainId_) external view returns (uint256);

    /**
     * @notice Adds a bridge to the multi bridge contract.
     * @param newBridge_ Address of the transmitter of the new bridge.
     */
    function addBridge(address newBridge_) external;

    /**
     * @notice Removes a bridge from the multi bridge contract.
     * @param removeBridge_ Address of the transmitter of the bridge to remove.
     */
    function removeBridge(address removeBridge_) external;

    /**
     * @notice Gets a list of accepted bridges.
     * @return List of address of the bridges.
     */
    function getBridges() external view returns (address[] memory);
}
