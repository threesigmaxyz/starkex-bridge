// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
 * @notice The default LayerZero messaging behaviour is blocking, i.e. any failed message will block the channel
 *         this abstract class try-catch all fail messages and store locally for future retry. hence, non-blocking
 *         NOTE: if the srcAddress is not configured properly, it will still block the message pathway from (srcChainId, srcAddress)
 */
interface INonblockingLzReceiver {
    /**
     * @notice Emitted when a message fails.
     * @param srcChainId The id of the source chain.
     * @param path The trusted path.
     * @param nonce The nonce of the message.
     * @param payload The payload of the message.
     * @param reason The reason of the failure.
     */
    event LogMessageFailed(
        uint16 indexed srcChainId, bytes indexed path, uint64 indexed nonce, bytes payload, bytes reason
    );

    /**
     * @notice Emitted when a message was succefully replayed.
     * @param srcChainId The id of the source chain.
     * @param path The trusted path.
     * @param nonce The nonce of the message.
     * @param payloadHash The hash of the payload of the message.
     */
    event LogRetryMessageSuccess(
        uint16 indexed srcChainId, bytes indexed path, uint64 indexed nonce, bytes32 payloadHash
    );

    error CallerMustBeLzReceiverError();
    error InvalidPayloadError();

    /**
     * @notice Should be called by the LzReceiver itself to process a message.
     * @dev The flow is lzReceive -> _blockingLzReceive -> nonblockingLzReceive -> _nonblockingLzReceive.
     * @param srcChaindId_ The id of the source chain.
     * @param path_ The trusted path.
     * @param nonce_ The nonce of the message.
     * @param payload_ The payload of the message.
     */
    function nonblockingLzReceive(uint16 srcChaindId_, bytes calldata path_, uint64 nonce_, bytes calldata payload_)
        external;

    /**
     * @notice Should be called by the LzReceiver itself to process a message.
     * @param srcChaindId_ The id of the source chain.
     * @param path_ The trusted path.
     * @param nonce_ The nonce of the message.
     * @param payload_ The payload of the message.
     */
    function retryMessage(uint16 srcChaindId_, bytes calldata path_, uint64 nonce_, bytes calldata payload_)
        external
        payable;
}
