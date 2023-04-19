// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILzTransmitter {
    /**
     * @notice Emitted when the address of the starkEx contract is set.
     * @param starkEx The address of the starkEx contract.
     */
    event LogSetStarkExAddress(address indexed starkEx);

    /**
     * @notice Emitted when a new message is sent.
     * @param dstChainId The id of the destination chain.
     * @param payload The payload to send.
     */
    event LogNewPayloadSent(uint16 indexed dstChainId, uint256 indexed sequenceNumber, bytes indexed payload);

    error StaleUpdateError(uint16 chainId, uint256 sequenceNumber);
    error ZeroStarkExAddressError();
    error ZeroLzEndpointAddressError();
    error InvalidEtherSentError();

    /**
     * @notice Gets a quote for the send fee of Layer Zero.
     * @param dstChainId_ The destination chain identifier.
     * @param payload_ The payload to send.
     * @return nativeFee_ The estimated fee in the chain native currency.
     * @return zroFee_ The estimated fee in Layer Zero's token (i.e., ZRO).
     */
    function getLayerZeroFee(uint16 dstChainId_, bytes memory payload_)
        external
        view
        returns (uint256 nativeFee_, uint256 zroFee_);

    /**
     *
     */
    /**
     * Transmitter Functions                                                                                                  **
     */
    /**
     *
     */

    /**
     * @notice Sends the payload to a chain.
     * @param dstChainId_ The id of the destination chain.
     * @param payload_ The payload to send.
     * @param refundAddress_ The refund address of the unused ether sent.
     */
    function keep(uint16 dstChainId_, bytes memory payload_, address payable refundAddress_) external payable;
}
