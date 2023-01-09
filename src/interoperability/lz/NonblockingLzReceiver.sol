// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LzReceiver } from "src/interoperability/lz/LzReceiver.sol";
import { INonblockingLzReceiver } from "src/interfaces/interoperability/lz/INonblockingLzReceiver.sol";
import { ExcessivelySafeCall } from "src/dependencies/lz/util/ExcessivelySafeCall.sol";

abstract contract NonblockingLzReceiver is INonblockingLzReceiver, LzReceiver {
    using ExcessivelySafeCall for address;

    constructor(address lzEndpoint_) LzReceiver(lzEndpoint_) { }

    /// @inheritdoc LzReceiver
    function _blockingLzReceive(uint16 srcChaindId_, bytes memory path_, uint64 nonce_, bytes memory payload_)
        internal
        virtual
        override
    {
        (bool success, bytes memory reason_) = address(this).excessivelySafeCall(
            gasleft(),
            150,
            abi.encodeWithSelector(this.nonblockingLzReceive.selector, srcChaindId_, path_, nonce_, payload_)
        );
        // Try-catch all errors/exceptions.
        if (!success) emit LogMessageFailed(srcChaindId_, path_, nonce_, payload_, reason_);
    }

    /// @inheritdoc INonblockingLzReceiver
    function nonblockingLzReceive(uint16 srcChaindId_, bytes calldata path_, uint64 nonce_, bytes calldata payload_)
        public
        virtual
        override
    {
        // Only internal transaction.
        if (_msgSender() != address(this)) revert CallerMustBeLzReceiverError();
        _nonblockingLzReceive(srcChaindId_, path_, nonce_, payload_);
    }

    /**
     * @notice Should be overriden. Defines the logic upon message receival.
     * @param srcChaindId_ The id of the source chain.
     * @param path_ The trusted path.
     * @param nonce_ The nonce of the message.
     * @param payload_ The payload of the message.
     */
    function _nonblockingLzReceive(uint16 srcChaindId_, bytes memory path_, uint64 nonce_, bytes memory payload_)
        internal
        virtual;
}