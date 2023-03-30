// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LzSender } from "src/interoperability/lz/LzSender.sol";
import { IBridgeTransmitter } from "src/interfaces/interoperability/IBridgeTransmitter.sol";

contract LzTransmitter is IBridgeTransmitter, LzSender {
    constructor(address lzEndpoint_) LzSender(lzEndpoint_) {
        if (lzEndpoint_ == address(0)) revert ZeroLzEndpointAddressError();
    }

    /// @inheritdoc IBridgeTransmitter
    function getFee(uint16 dstChainId_, bytes memory payload_) public view override returns (uint256 nativeFee_) {
        (nativeFee_,) = lzEndpoint.estimateFees(dstChainId_, address(this), payload_, false, "");
        return nativeFee_;
    }

    //=====================================================================================================================//
    //=== Transmitter Functions                                                                                         ===//
    //=====================================================================================================================//

    /// @inheritdoc IBridgeTransmitter
    function keep(uint16 dstChainId_, address payable refundAddress_, bytes memory payload_)
        external
        payable
        override
    {
        _send(dstChainId_, payload_, refundAddress_, msg.value);
    }

    /// @inheritdoc IBridgeTransmitter
    function batchKeep(
        uint16[] calldata dstChainIds_,
        uint256[] calldata nativeFees_,
        address payable refundAddress_,
        bytes memory payload_
    ) external payable override {
        uint256 etherSent;
        for (uint256 i_ = 0; i_ < nativeFees_.length;) {
            etherSent += nativeFees_[i_];
            unchecked {
                ++i_;
            }
        }
        if (etherSent != msg.value) revert InvalidEtherSentError();

        for (uint256 i_ = 0; i_ < dstChainIds_.length;) {
            _send(dstChainIds_[i_], payload_, refundAddress_, nativeFees_[i_]);
            unchecked {
                ++i_;
            }
        }
    }

    function _send(uint16 dstChainId_, bytes memory orderRoot_, address payable refundAddress_, uint256 nativeFee_)
        internal
    {
        _lzSend(dstChainId_, orderRoot_, refundAddress_, address(0x0), "", nativeFee_);
        emit LogNewOrderRootSent(dstChainId_, orderRoot_);
    }
}
