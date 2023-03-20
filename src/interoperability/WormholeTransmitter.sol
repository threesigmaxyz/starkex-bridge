// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { WormholeBase } from "src/interoperability/wormhole/WormholeBase.sol";
import { IWormholeTransmitter } from "src/interfaces/interoperability/IWormholeTransmitter.sol";
import { IStarkEx } from "src/interfaces/interoperability/IStarkEx.sol";
import { IRelayProvider } from "src/dependencies/wormhole/interfaces/IRelayProvider.sol";
import { ICoreRelayer } from "src/dependencies/wormhole/interfaces/ICoreRelayer.sol";

contract WormholeTransmitter is IWormholeTransmitter, WormholeBase {
    /// @notice Address of the starkEx contract.
    IStarkEx private immutable _starkEx;

    /// @notice Record the last sent sequence number. Avoids sending repeated roots.
    mapping(uint16 => uint256) private _lastUpdated;

    /// @notice Number assigned to each message.
    uint32 private _nonce;

    constructor(address wormholeBridge_, address relayer_, address starkExAddress_)
        WormholeBase(wormholeBridge_, relayer_)
    {
        if (wormholeBridge_ == address(0)) revert ZeroWormholeAddressError();
        if (relayer_ == address(0)) revert ZeroRelayerAddressError();
        if (starkExAddress_ == address(0)) revert ZeroStarkExAddressError();

        _starkEx = IStarkEx(starkExAddress_);
        //_relayProvider = relayer.getDefaultRelayProvider();

        emit LogSetStarkExAddress(starkExAddress_);
    }

    /// @inheritdoc IWormholeTransmitter
    function getPayload() public view override returns (bytes memory payload_) {
        return abi.encode(_starkEx.getOrderRoot());
    }

    /// @inheritdoc IWormholeTransmitter
    function getWormholeFee(uint16 dstChainId_) external override returns (uint256) {
        uint256 fee_ = wormhole.messageFee();
        uint256 deliveryCost_ = relayer.quoteGasDeliveryFee(dstChainId_, 500_000, relayer.getDefaultRelayProvider());
        uint256 applicationBudget_ =
            relayer.quoteApplicationBudgetFee(dstChainId_, 100, relayer.getDefaultRelayProvider());
        return fee_ + deliveryCost_ + applicationBudget_;
    }

    /// @inheritdoc IWormholeTransmitter
    function keep(uint16 dstChainId_, address payable refundAddress_) external payable override {
        uint256 sequenceNumber_ = _starkEx.getSequenceNumber();
        _updateSequenceNumber(dstChainId_, sequenceNumber_);
        bytes memory orderRoot_ = getPayload();

        _send(dstChainId_, orderRoot_, sequenceNumber_, refundAddress_, msg.value);
    }

    /// @inheritdoc IWormholeTransmitter
    function batchKeep(uint16[] calldata dstChainIds_, uint256[] calldata nativeFees_, address payable refundAddress_)
        external
        payable
        override
    {
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
            _send(dstChainIds_[i_], orderRoot_, sequenceNumber_, refundAddress_, nativeFees_[i_]);
            unchecked {
                ++i_;
            }
        }
    }

    function _send(
        uint16 dstChainId_,
        bytes memory orderRoot_,
        uint256 sequenceNumber_,
        address payable refundAddress_,
        uint256 nativeFee_
    ) internal {
        bytes memory trustedRemote = trustedRemoteLookup[dstChainId_];
        if (trustedRemote.length == 0) revert RemoteChainNotTrustedError();

        uint256 msgFee_ = wormhole.messageFee();
        uint256 relayFee_ = nativeFee_ - msgFee_;
        (uint256 orderRootD_) = abi.decode(orderRoot_, (uint256));
        bytes memory payload_ = abi.encode(orderRootD_, trustedRemote);

        // Publish message for delivery.
        wormhole.publishMessage{ value: msgFee_ }(_nonce, payload_, 1);

        // Request for message to be delivered using relay.
        ICoreRelayer.DeliveryRequest memory request_ = ICoreRelayer.DeliveryRequest(
            dstChainId_, //targetChain
            bytes32(trustedRemote), //targetAddress
            bytes32(uint256(uint160(address(refundAddress_)))), //refundAddress
            relayFee_, //computeBudget
            0, //applicationBudget
            relayer.getDefaultRelayParams() //relayerParams
        );

        relayer.requestDelivery{ value: relayFee_ }(request_, _nonce, relayer.getDefaultRelayProvider());

        _nonce++;

        emit LogNewOrderRootSent(dstChainId_, sequenceNumber_, orderRoot_);
    }

    function _updateSequenceNumber(uint16 dstChainId_, uint256 sequenceNumber_) internal {
        uint256 lastUpdated_ = _lastUpdated[dstChainId_];
        if (sequenceNumber_ <= lastUpdated_) revert StaleUpdateError(dstChainId_, lastUpdated_);
        _lastUpdated[dstChainId_] = sequenceNumber_;
    }
}
