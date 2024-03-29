// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILzTransmitter {
    /**
     * @notice Emitted when the address of the starkEx contract is set.
     * @param starkEx The address of the starkEx contract.
     */
    event LogSetStarkExAddress(address indexed starkEx);

    /**
     * @notice Emitted when a new order root is sent.
     * @param dstChainId The id of the destination chain.
     * @param orderRoot The root of the order tree.
     */
    event LogNewOrderRootSent(uint16 indexed dstChainId, uint256 indexed sequenceNumber, bytes indexed orderRoot);

    error StaleUpdateError(uint16 chainId, uint256 sequenceNumber);
    error ZeroStarkExAddressError();
    error ZeroLzEndpointAddressError();
    error InvalidEtherSentError();

    /**
     * @notice Gets the starkEx order root to send to the LzReceptor in the sideChains.
     * @return payload_ The payload of the message.
     */
    function getPayload() external view returns (bytes memory payload_);

    /**
     * @notice Gets a quote for the send fee of Layer Zero.
     * @param dstChainId_ The destination chain identifier
     * @return nativeFee_ The estimated fee in the chain native currency.
     * @return zroFee_ The estimated fee in Layer Zero's token (i.e., ZRO).
     */
    function getLayerZeroFee(uint16 dstChainId_) external view returns (uint256 nativeFee_, uint256 zroFee_);

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
     * @notice Updates the order root of the interoperability contract in the sideChain.
     * @param dstChainId_ The id of the destination chain.
     * @param refundAddress_ The refund address of the unused ether sent.
     */
    function keep(uint16 dstChainId_, address payable refundAddress_) external payable;

    /**
     * @notice Updates the order roots of the interoperability contracts in the selected sideChains.
     * @param dstChainIds_ The if of the destination chains.
     * @param refundAddress_ The refund address of the unused ether sent.
     */
    function batchKeep(
        uint16[] calldata dstChainIds_,
        uint256[] calldata valueToChainId,
        address payable refundAddress_
    ) external payable;
}
