// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ILayerZeroReceiverUserApplicationConfig } from "src/dependencies/lz/interfaces/ILayerZeroReceiverUserApplicationConfig.sol";
import { ILayerZeroReceiver }                      from "src/dependencies/lz/interfaces/ILayerZeroReceiver.sol";
import { LzBase }                                  from "src/dependencies/lz/LzBase.sol";

abstract contract LzReceiver is ILayerZeroReceiver, ILayerZeroReceiverUserApplicationConfig, LzBase {

    constructor(address _endpoint) LzBase(_endpoint) {}

    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) public virtual override {
        // lzReceive must be called by the endpoint for security
        require(_msgSender() == address(lzEndpoint), "LzApp: invalid endpoint caller");

        bytes memory trustedRemote = trustedRemoteLookup[_srcChainId];
        // if will still block the message pathway from (srcChainId, srcAddress). should not receive message from untrusted remote.
        require(_srcAddress.length == trustedRemote.length && trustedRemote.length > 0 && keccak256(_srcAddress) == keccak256(trustedRemote), "LzApp: invalid source sending contract");

        _blockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    // abstract function - the default behaviour of LayerZero is blocking. See: NonblockingLzApp if you dont need to enforce ordered messaging
    function _blockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual;

    function setReceiveVersion(uint16 _version) external override onlyOwner {
        lzEndpoint.setReceiveVersion(_version);
    }

    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external override onlyOwner {
        lzEndpoint.forceResumeReceive(_srcChainId, _srcAddress);
    }
}