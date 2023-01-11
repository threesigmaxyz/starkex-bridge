// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ILzReceiver } from "src/interfaces/interoperability/lz/ILzReceiver.sol";
import { LzBase } from "src/interoperability/lz/LzBase.sol";

abstract contract LzReceiver is ILzReceiver, LzBase {
    constructor(address _endpoint) LzBase(_endpoint) { }

    /// @inheritdoc ILzReceiver
    function lzReceive(uint16 srcChaindId_, bytes calldata path_, uint64 nonce_, bytes calldata payload_)
        public
        virtual
        override
    {
        // LzReceive must be called by the endpoint for security.
        if (_msgSender() != address(lzEndpoint)) revert InvalidEndpointCallerError();

        bytes memory trustedRemote = trustedRemoteLookup[srcChaindId_];
        // It will still block the message pathway from (srcChainId, srcAddress).
        // Should not receive message from untrusted remote.
        if (
            path_.length != trustedRemote.length || trustedRemote.length <= 0
                || keccak256(path_) != keccak256(trustedRemote)
        ) revert RemoteChainNotTrustedError();

        _blockingLzReceive(srcChaindId_, path_, nonce_, payload_);
    }

    /**
     * @notice Function to be overriden to define the behaviour when a message is received.
     * @dev The default behaviour of LayerZero is blocking.
     *         See: NonblockingLzApp if you dont need to enforce ordered messaging.
     * @param srcChaindId_ The id of the source chain.
     * @param path_ The trusted path.
     * @param nonce_ The nonce of the message.
     * @param payload_ The payload of the message.
     */
    function _blockingLzReceive(uint16 srcChaindId_, bytes memory path_, uint64 nonce_, bytes memory payload_)
        internal
        virtual;

    /// @inheritdoc ILzReceiver
    function setReceiveVersion(uint16 version_) external override onlyOwner {
        lzEndpoint.setReceiveVersion(version_);
    }

    /// @inheritdoc ILzReceiver
    function forceResumeReceive(uint16 srcChaindId_, bytes calldata path_) external override onlyOwner {
        lzEndpoint.forceResumeReceive(srcChaindId_, path_);
    }
}
