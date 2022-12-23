// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Pausable } from "@openzeppelin/security/Pausable.sol";
import { IStarkEx } from "src/interfaces/interoperability/IStarkEx.sol";
import { LzSender } from "src/interoperability/lz/LzSender.sol";
import { ILzTransmitter } from "src/interfaces/interoperability/ILzTransmitter.sol";

contract LzTransmitter is ILzTransmitter, LzSender, Pausable {
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
    function getStarkEx() external view override returns (address starkEx_) {
        starkEx_ = address(_starkEx);
    }

    /// @inheritdoc ILzTransmitter
    function getLastUpdatedSequenceNumber(uint16 chainId_) external view override returns (uint256 lastUpdated_) {
        lastUpdated_ = _lastUpdated[chainId_];
    }

    /// @inheritdoc ILzTransmitter
    function getPayload() public view override returns (bytes memory payload_) {
        return abi.encode(_starkEx.getOrderRoot());
    }

    /// @inheritdoc ILzTransmitter
    function getLayerZeroFee(uint16 dstChainId_, bool useZro_, bytes calldata adapterParams_)
        public
        view
        override
        returns (uint256 nativeFee_, uint256 zroFee_)
    {
        return lzEndpoint.estimateFees(dstChainId_, address(this), getPayload(), useZro_, adapterParams_);
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
        _keep(dstChainId_, refundAddress_, msg.value);
    }

    /// @inheritdoc ILzTransmitter
    function batchKeep(uint16[] calldata dstChainIds_, address payable refundAddress_) external payable override {
        uint256 dstChainIdsLength = dstChainIds_.length;

        for (uint256 i = 0; i < dstChainIdsLength; i++) {
            _keep(dstChainIds_[i], refundAddress_, msg.value / dstChainIdsLength);
        }
    }

    /**
     * @notice Updates the order root of the interoperability contract in the sideChain.
     * @param dstChainId_ The id of the destination chain.
     * @param refundAddress_ The refund address of the unused ether sent.
     * @param usableGasInEther_ The usable gas, in ether, to run code in the sidechain.
     */
    function _keep(uint16 dstChainId_, address payable refundAddress_, uint256 usableGasInEther_) internal {
        uint256 sequenceNumber_ = _starkEx.getSequenceNumber();
        uint256 lastUpdated_ = _lastUpdated[dstChainId_];

        /// Not worth sending the same or an old root.
        if (sequenceNumber_ <= lastUpdated_) revert StaleUpdateError(dstChainId_, lastUpdated_);

        _lastUpdated[dstChainId_] = sequenceNumber_;

        uint256 orderRoot_ = _starkEx.getOrderRoot();

        _lzSend(dstChainId_, abi.encode(orderRoot_), refundAddress_, address(0x0), "", usableGasInEther_);
        emit LogNewOrderRootSent(dstChainId_, orderRoot_);
    }
}
