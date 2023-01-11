// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILzSender {
    /**
     * @notice Emitted when the minimum destination gas is set for a chain.
     * @param dstChainId The id of the destination chain.
     * @param packetType The type of the packet.
     * @param minDstGas The minimum destination gas.
     */
    event LogSetMinDstGas(uint16 indexed dstChainId, uint16 indexed packetType, uint256 indexed minDstGas);

    error ZeroGasLimitError();
    error GasLimitToolowError();
    error InvalidAdapterParamsError();

    /**
     * @notice Sets the send version.
     * @param version_ The version.
     */
    function setSendVersion(uint16 version_) external;

    /**
     * @notice sets the minimum destination gas.
     * @param dstChainId_ The id of the destination chain.
     * @param packetType_ The type of the packet to send.
     * @param minGas_ The minimum gas to set.
     */
    function setMinDstGas(uint16 dstChainId_, uint16 packetType_, uint256 minGas_) external;
}
