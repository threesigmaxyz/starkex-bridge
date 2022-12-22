// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LzReceiver }          from "src/dependencies/lz/LzReceiver.sol";

/*
 * the default LayerZero messaging behaviour is blocking, i.e. any failed message will block the channel
 * this abstract class try-catch all fail messages and store locally for future retry. hence, non-blocking
 * NOTE: if the srcAddress is not configured properly, it will still block the message pathway from (srcChainId, srcAddress)
 */
interface INonblockingLzReceiver {

    event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason);
    event RetryMessageSuccess(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _payloadHash);

    function nonblockingLzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external virtual;

    function retryMessage(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external payable virtual;
}