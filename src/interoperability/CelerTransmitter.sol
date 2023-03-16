// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { CelerBase } from "src/interoperability/celer/CelerBase.sol";
import { ICelerTransmitter } from "src/interfaces/interoperability/ICelerTransmitter.sol";
import { IStarkEx } from "src/interfaces/interoperability/IStarkEx.sol";
import { IMessageBus } from "src/dependencies/celer/interfaces/IMessageBus.sol";

contract CelerTransmitter is ICelerTransmitter, CelerBase {
    /// @notice Address of the starkEx contract.
    IStarkEx private immutable _starkEx;

    /// @notice Record the last sent sequence number. Avoids sending repeated roots.
    mapping(uint16 => uint256) private _lastUpdated;

    constructor(address messageBus_, address starkExAddress_) CelerBase(messageBus_) {
        if (messageBus_ == address(0)) revert ZeroCelerAddressError();
        if (starkExAddress_ == address(0)) revert ZeroStarkExAddressError();

        _starkEx = IStarkEx(starkExAddress_);

        emit LogSetStarkExAddress(starkExAddress_);
    }

    /// @inheritdoc ICelerTransmitter
    function getPayload() public view override returns (bytes memory payload_) {
        return abi.encode(_starkEx.getOrderRoot());
    }

    /// @inheritdoc ICelerTransmitter
    function getCelerFee(address to_, bytes calldata data_) external view override returns (uint256) {
        return messageBus.calcFee(abi.encode(data_, to_));
    }

    /// @inheritdoc ICelerTransmitter
    function keep(uint16 dstChainId_, address payable) external payable override {
        // refundAddress???
        uint256 sequenceNumber_ = _starkEx.getSequenceNumber();
        _updateSequenceNumber(dstChainId_, sequenceNumber_);
        bytes memory orderRoot_ = getPayload();

        _send(dstChainId_, orderRoot_, sequenceNumber_, msg.value);
    }

    /// @inheritdoc ICelerTransmitter
    function batchKeep(uint16[] calldata dstChainIds_, uint256[] calldata nativeFees_, address payable)
        external
        payable
        override
    {
        // refundAddress???
        uint256 etherSent_;
        for (uint256 i_ = 0; i_ < nativeFees_.length;) {
            etherSent_ += nativeFees_[i_];
            unchecked {
                ++i_;
            }
        }
        if (etherSent_ != msg.value) revert InvalidEtherSentError();

        bytes memory orderRoot_ = getPayload();
        uint256 sequenceNumber_ = _starkEx.getSequenceNumber();

        for (uint256 i_ = 0; i_ < dstChainIds_.length;) {
            _updateSequenceNumber(dstChainIds_[i_], sequenceNumber_);
            _send(dstChainIds_[i_], orderRoot_, sequenceNumber_, nativeFees_[i_]);
            unchecked {
                ++i_;
            }
        }
    }

    function _send(uint16 dstChainId_, bytes memory orderRoot_, uint256 sequenceNumber_, uint256 nativeFee_) internal {
        // refundAddress???
        bytes memory trustedRemote_ = trustedRemoteLookup[dstChainId_];
        if (trustedRemote_.length == 0) revert RemoteChainNotTrustedError();

        (uint256 orderRootD_) = abi.decode(orderRoot_, (uint256));
        bytes memory payload_ = abi.encode(orderRootD_, trustedRemote_);

        messageBus.sendMessage{ value: nativeFee_ }(trustedRemote_, dstChainId_, payload_);

        emit LogNewOrderRootSent(dstChainId_, sequenceNumber_, orderRoot_);
    }

    function _updateSequenceNumber(uint16 dstChainId_, uint256 sequenceNumber_) internal {
        uint256 lastUpdated_ = _lastUpdated[dstChainId_];
        if (sequenceNumber_ <= lastUpdated_) revert StaleUpdateError(dstChainId_, lastUpdated_);
        _lastUpdated[dstChainId_] = sequenceNumber_;
    }
}
