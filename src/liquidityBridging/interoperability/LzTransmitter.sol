// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IStarkEx } from "src/interfaces/interoperability/IStarkEx.sol";
import { LzSender } from "src/interoperability/lz/LzSender.sol";
import { ILzTransmitter } from "src/liquidityBridging/interfaces/ILzTransmitter.sol";

contract LzTransmitter is ILzTransmitter, LzSender {
    /// @notice Address of the starkEx contract.
    IStarkEx private immutable _starkEx;

    /// @notice Record the last sent sequence number.
    mapping(uint16 => uint256) private _lastUpdated;

    constructor(address lzEndpoint_, address starkExAddress_) LzSender(lzEndpoint_) {
        if (lzEndpoint_ == address(0)) revert ZeroLzEndpointAddressError();
        if (starkExAddress_ == address(0)) revert ZeroStarkExAddressError();

        _starkEx = IStarkEx(starkExAddress_);

        emit LogSetStarkExAddress(starkExAddress_);
    }

    /// @inheritdoc ILzTransmitter
    function getLayerZeroFee(uint16 dstChainId_, bytes memory payload_)
        public
        view
        override
        returns (uint256 nativeFee_, uint256 zroFee_)
    {
        return lzEndpoint.estimateFees(dstChainId_, address(this), payload_, false, "");
    }

    /**
     *
     */
    /**
     * Transmitter Functions                                                                                                  **
     */
    /**
     *
     */

    /// @inheritdoc ILzTransmitter
    function keep(uint16 dstChainId_, bytes memory payload_, address payable refundAddress_)
        external
        payable
        override
    {
        uint256 sequenceNumber_ = _starkEx.getSequenceNumber();
        _updateSequenceNumber(dstChainId_, sequenceNumber_);

        _send(dstChainId_, payload_, sequenceNumber_, refundAddress_, msg.value);
    }

    function _send(
        uint16 dstChainId_,
        bytes memory payload_,
        uint256 sequenceNumber_,
        address payable refundAddress_,
        uint256 nativeFee_
    ) internal {
        _lzSend(dstChainId_, payload_, refundAddress_, address(0x0), "", nativeFee_);
        emit LogNewPayloadSent(dstChainId_, sequenceNumber_, payload_);
    }

    function _updateSequenceNumber(uint16 dstChainId_, uint256 sequenceNumber_) internal {
        uint256 lastUpdated_ = _lastUpdated[dstChainId_];
        if (sequenceNumber_ <= lastUpdated_) revert StaleUpdateError(dstChainId_, lastUpdated_);
        _lastUpdated[dstChainId_] = sequenceNumber_;
    }
}
