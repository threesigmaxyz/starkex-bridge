// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IStarkEx } from "src/interfaces/interoperability/IStarkEx.sol";
import { LzSender } from "src/interoperability/lz/LzSender.sol";
import { ILzTransmitter } from "src/interfaces/interoperability/ILzTransmitter.sol";

contract LzTransmitter is ILzTransmitter, LzSender {
    /// @notice Address of the starkEx contract.
    IStarkEx private immutable _starkEx;

    /// @notice Record the last sent sequence number. Avoids sending repeated roots.
    mapping(uint16 => uint256) private _lastUpdated;

    constructor(address lzEndpoint_, address starkExAddress_) LzSender(lzEndpoint_) {
        if (lzEndpoint_ == address(0)) revert ZeroLzEndpointAddressError();
        if (starkExAddress_ == address(0)) revert ZeroStarkExAddressError();

        _starkEx = IStarkEx(starkExAddress_);

        emit LogSetStarkExAddress(starkExAddress_);
    }

    /// @inheritdoc ILzTransmitter
    function getPayload() public view override returns (bytes memory payload_) {
        return abi.encode(_starkEx.getOrderRoot());
    }

    /// @inheritdoc ILzTransmitter
    function getLayerZeroFee(uint16 dstChainId_) public view override returns (uint256 nativeFee_, uint256 zroFee_) {
        return lzEndpoint.estimateFees(dstChainId_, address(this), getPayload(), false, "");
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
    function keep(uint16 dstChainId_, address payable refundAddress_) external payable override {
        uint256 sequenceNumber_ = _starkEx.getSequenceNumber();
        _updateSequenceNumber(dstChainId_, sequenceNumber_);
        bytes memory orderRoot_ = getPayload();

        _send(dstChainId_, orderRoot_, sequenceNumber_, refundAddress_, msg.value);
    }

    /// @inheritdoc ILzTransmitter
    function batchKeep(uint16[] calldata dstChainIds_, uint256[] calldata nativeFees_, address payable refundAddress_)
        external
        payable
        override
    {
        uint256 etherSent;
        for (uint256 i = 0; i < nativeFees_.length; i++) {
            etherSent += nativeFees_[i];
        }
        if (etherSent != msg.value) revert InvalidEtherSentError();

        bytes memory orderRoot_ = getPayload();
        uint256 sequenceNumber_ = _starkEx.getSequenceNumber();

        for (uint256 i = 0; i < dstChainIds_.length; i++) {
            _updateSequenceNumber(dstChainIds_[i], sequenceNumber_);
            _send(dstChainIds_[i], orderRoot_, sequenceNumber_, refundAddress_, nativeFees_[i]);
        }
    }

    function _send(
        uint16 dstChainId_,
        bytes memory orderRoot_,
        uint256 sequenceNumber_,
        address payable refundAddress_,
        uint256 nativeFee_
    ) internal {
        _lzSend(dstChainId_, orderRoot_, refundAddress_, address(0x0), "", nativeFee_);
        emit LogNewOrderRootSent(dstChainId_, sequenceNumber_, orderRoot_);
    }

    function _updateSequenceNumber(uint16 dstChainId_, uint256 sequenceNumber_) internal {
        uint256 lastUpdated_ = _lastUpdated[dstChainId_];
        if (sequenceNumber_ <= lastUpdated_) revert StaleUpdateError(dstChainId_, lastUpdated_);
        _lastUpdated[dstChainId_] = sequenceNumber_;
    }
}
