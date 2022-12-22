// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Pausable } from "@openzeppelin/security/Pausable.sol";

import { LzSender } from "src/dependencies/lz/LzSender.sol";

interface IStarkEx {
    function getValidiumVaultRoot() external view returns (uint256);
    function getValidiumTreeHeight() external view returns (uint256);
    function getRollupVaultRoot() external view returns (uint256);
    function getRollupTreeHeight() external view returns (uint256);
    function getOrderRoot() external view returns (uint256);
    function getOrderTreeHeight() external view returns (uint256);
    function getSequenceNumber() external view returns (uint256);
}

contract LzTransmitter is LzSender, Pausable {

    IStarkEx immutable private _starkEx;
    mapping(uint16 => uint256) private _lastUpdated;

    error StaleUpdateError(uint16 chainId, uint256 sequenceNumber);
    error ZeroStarkExAddressError();
    error ZeroLzEndpointAddressError();

    event LogSetStarkExAddress(address starkEx);
    event LogNewOrderRootSent(uint256 orderRoot);

    constructor(address lzEndpoint_, address starkExAddress_) LzSender(lzEndpoint_) {
        if (lzEndpoint_ == address(0)) revert ZeroLzEndpointAddressError();
        if (starkExAddress_ == address(0)) revert ZeroStarkExAddressError();

        _starkEx = IStarkEx(starkExAddress_);

        emit LogSetStarkExAddress(starkExAddress_);
    }

    /** 
     * @notice Gets the StarkEx address.
     * @return starkEx_ The StarkEx address.
     */
    function getStarkEx() external view returns(address starkEx_) {
        starkEx_ = address(_starkEx);
    }

    /** 
     * @notice Gets the sequence number of the last StarkEx update processed.
     * @param chainId_ The id of the sideChain.
     * @return lastUpdated_ The last StarkEx update processed.
     */
    function getLastUpdatedSequenceNumber(uint16 chainId_) external view returns(uint256 lastUpdated_) {
        lastUpdated_ = _lastUpdated[chainId_];
    }

    /** 
     * @notice Gets the starkEx order root to send to the LzReceptor in the sideChains.
     * @return payload_ The payload of the message.
     */
    function getPayload() public view returns (bytes memory payload_) {
        return abi.encode(_starkEx.getOrderRoot());
    }

    /** 
     * @notice Gets a quote for the send fee of Layer Zero.
     * @param dstChainId_ The destination chain identifier
     * @param useZro_ Whether the Layer Zero's token (ZRO) will be used to pay for fees.
     * @param adapterParams_ The custom parameters for the adapter service.
     * @return nativeFee_ The estimated fee in the chain native currency.
     * @return zroFee_ The estimated fee in Layer Zero's token (i.e., ZRO).
     */
    function getLayerZeroFee(
        uint16 dstChainId_,
        bool useZro_,
        bytes calldata adapterParams_
    ) public view returns (
        uint nativeFee_,
        uint zroFee_
    ) {
        return lzEndpoint.estimateFees(dstChainId_, address(this), getPayload(), useZro_, adapterParams_);
    }

    /******************************************************************************************************************************/
    /*** Transmitter Functions                                                                                                  ***/
    /******************************************************************************************************************************/

    // TODO send to multiple chains https://layerzero.gitbook.io/docs/faq/messaging-properties#multi-send
    function keep(
        uint16 dstChainId_,
        address payable refundAddress_
    ) public payable whenNotPaused {
        uint256 sequenceNumber_ = _starkEx.getSequenceNumber();
        uint256 lastUpdated_ = _lastUpdated[dstChainId_];
        
        /// @dev Not worth sending the same or an old root.
        if (sequenceNumber_ <= lastUpdated_) revert StaleUpdateError(dstChainId_, lastUpdated_);
        
        _lastUpdated[dstChainId_] = sequenceNumber_;

        uint256 orderRoot_ = _starkEx.getOrderRoot();

        _lzSend(dstChainId_, abi.encode(orderRoot_), refundAddress_, address(0x0), "", msg.value);
        emit LogNewOrderRootSent(orderRoot_);
    }
}