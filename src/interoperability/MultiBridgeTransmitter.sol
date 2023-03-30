// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable2Step } from "@openzeppelin/access/Ownable2Step.sol";
import { IStarkEx } from "src/interfaces/interoperability/IStarkEx.sol";
import { IMultiBridgeTransmitter } from "src/interfaces/interoperability/IMultiBridgeTransmitter.sol";
import { IBridgeTransmitter } from "src/interfaces/interoperability/IBridgeTransmitter.sol";

contract MultiBridgeTransmitter is IMultiBridgeTransmitter, Ownable2Step {
    /// @notice List of bridge transmitters.
    address[] private _bridgeTransmitters;

    /// @notice Record the last sent sequence number. Avoids sending repeated roots.
    mapping(uint16 => uint256) private _lastUpdated;

    /// @notice Address of the starkEx contract.
    IStarkEx private immutable _starkEx;

    constructor(address starkExAddress_) {
        if (starkExAddress_ == address(0)) revert ZeroStarkExAddressError();

        _starkEx = IStarkEx(starkExAddress_);

        emit LogSetStarkExAddress(starkExAddress_);
    }

    /// @inheritdoc IMultiBridgeTransmitter
    function getPayload() public view override returns (bytes memory payload_) {
        return abi.encode(_starkEx.getOrderRoot());
    }

    /// @inheritdoc IMultiBridgeTransmitter
    function send(uint16 dstChainId_, address payable refundAddress_) external payable override {
        uint256 totalFee_;
        uint256 totalBridges_ = _bridgeTransmitters.length;
        bytes memory orderRoot_ = getPayload();

        //  Avoids sending repeated roots.
        uint256 sequenceNumber_ = _starkEx.getSequenceNumber();
        _updateSequenceNumber(dstChainId_, sequenceNumber_);

        //  Add sequenceNumber to payload to check order in receptor.
        bytes memory payload_ = abi.encode(orderRoot_, sequenceNumber_);

        //  Transmit the payload through all bridges.
        for (uint256 i_ = 0; i_ < totalBridges_;) {
            address currentBridge_ = _bridgeTransmitters[i_];
            uint256 fee_ = IBridgeTransmitter(currentBridge_).getFee(dstChainId_, payload_);

            //  Send the payload without halting the process if a bridge fails.
            try IBridgeTransmitter(currentBridge_).keep{ value: fee_ }(dstChainId_, refundAddress_, payload_) {
                totalFee_ += fee_;
                emit LogTransmitSuccess(currentBridge_, dstChainId_, sequenceNumber_, orderRoot_);
            } catch {
                emit LogTransmitFailed(currentBridge_, dstChainId_, sequenceNumber_, orderRoot_);
            }

            unchecked {
                ++i_;
            }
        }

        emit LogMultiBridgeMsgSend(dstChainId_, sequenceNumber_, orderRoot_);

        //  Refund if necessary.
        if (totalFee_ < msg.value) {
            _refund(refundAddress_, msg.value - totalFee_);
        }
    }

    /// @inheritdoc IMultiBridgeTransmitter
    function sendBatch(uint16[] memory dstChainId_, address payable refundAddress_) external payable override {
        uint256 totalFee_;
        uint256 totalBridges_ = _bridgeTransmitters.length;
        bytes memory orderRoot_ = getPayload();
        uint256[] memory fees_ = new uint256[](dstChainId_.length);

        //  Avoids sending repeated roots.
        uint256 sequenceNumber_ = _starkEx.getSequenceNumber();
        for (uint256 y_ = 0; y_ < dstChainId_.length;) {
            _updateSequenceNumber(dstChainId_[y_], sequenceNumber_);
            unchecked {
                ++y_;
            }
        }

        //  Add sequenceNumber to payload to check order in receptor.
        bytes memory payload_ = abi.encode(orderRoot_, sequenceNumber_);

        //  Transmit the payload through all bridges.
        for (uint256 i_ = 0; i_ < totalBridges_;) {
            address currentBridge_ = _bridgeTransmitters[i_];
            uint256 accuFee_ = 0;
            //  Calculate the fees for sending the batch transaction.
            for (uint256 f_ = 0; f_ < dstChainId_.length;) {
                fees_[f_] = IBridgeTransmitter(currentBridge_).getFee(dstChainId_[f_], payload_);
                accuFee_ += fees_[f_];
                unchecked {
                    ++f_;
                }
            }

            //  Send the payload without halting the process if a bridge fails.
            try IBridgeTransmitter(currentBridge_).batchKeep{ value: accuFee_ }(
                dstChainId_, fees_, refundAddress_, payload_
            ) {
                totalFee_ += accuFee_;
                emit LogBatchTransmitSuccess(currentBridge_, dstChainId_, sequenceNumber_, orderRoot_);
            } catch {
                emit LogBatchTransmitFailed(currentBridge_, dstChainId_, sequenceNumber_, orderRoot_);
            }

            unchecked {
                ++i_;
            }
        }

        emit LogMultiBridgeMsgBatchSend(dstChainId_, sequenceNumber_, orderRoot_);

        //  Refund if necessary.
        if (totalFee_ < msg.value) {
            _refund(refundAddress_, msg.value - totalFee_);
        }
    }

    /// @inheritdoc IMultiBridgeTransmitter
    function calcTotalFee(uint16 dstChainId_) external view override returns (uint256) {
        uint256 totalFee_;
        uint256 totalBridges_ = _bridgeTransmitters.length;
        bytes memory orderRoot_ = getPayload();
        uint256 sequenceNumber_ = _starkEx.getSequenceNumber();
        bytes memory payload_ = abi.encode(orderRoot_, sequenceNumber_);

        // Calculate fee for all bridges.
        for (uint256 i_ = 0; i_ < totalBridges_;) {
            address currentBridge_ = _bridgeTransmitters[i_];
            uint256 fee_ = IBridgeTransmitter(currentBridge_).getFee(dstChainId_, payload_);

            totalFee_ += fee_;

            unchecked {
                ++i_;
            }
        }

        return totalFee_;
    }

    /// @inheritdoc IMultiBridgeTransmitter
    function addBridge(address newBridge_) external override onlyOwner {
        uint256 totalBridges_ = _bridgeTransmitters.length;

        for (uint256 i_; i_ < totalBridges_;) {
            if (_bridgeTransmitters[i_] == newBridge_) revert BridgeAlreadyAddedError();

            unchecked {
                ++i_;
            }
        }

        _bridgeTransmitters.push(newBridge_);
        emit LogNewBridgeAdded(newBridge_);
    }

    /// @inheritdoc IMultiBridgeTransmitter
    function removeBridge(address removeBridge_) external override onlyOwner {
        uint256 lastIndex_ = _bridgeTransmitters.length - 1;
        uint256 i_;

        while (_bridgeTransmitters[i_] != removeBridge_) {
            ++i_;
            if (i_ > lastIndex_) revert BridgeNotInListError();
        }

        if (i_ < lastIndex_) {
            _bridgeTransmitters[i_] = _bridgeTransmitters[lastIndex_];
        }

        _bridgeTransmitters.pop();

        emit LogBridgeRemoved(removeBridge_);
    }

    /// @inheritdoc IMultiBridgeTransmitter
    function getBridges() external view override returns (address[] memory) {
        return _bridgeTransmitters;
    }

    function _updateSequenceNumber(uint16 dstChainId_, uint256 sequenceNumber_) internal {
        uint256 lastUpdated_ = _lastUpdated[dstChainId_];
        if (sequenceNumber_ <= lastUpdated_) revert StaleUpdateError(dstChainId_, lastUpdated_);
        _lastUpdated[dstChainId_] = sequenceNumber_;
    }

    function _refund(address to_, uint256 value_) internal {
        (bool success_,) = to_.call{ value: value_ }("");
        if (!success_) revert RefundError();
    }
}
