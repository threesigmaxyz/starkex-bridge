// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { ICelerBase } from "src/interfaces/interoperability/celer/ICelerBase.sol";
import { IMessageBus } from "src/dependencies/celer/interfaces/IMessageBus.sol";

abstract contract CelerBase is ICelerBase, Ownable {
    /// @notice The trusted address in each remote chain.
    mapping(uint16 => bytes) public trustedRemoteLookup;

    /// @notice The message bus address.
    IMessageBus public immutable messageBus;

    constructor(address messageBus_) {
        messageBus = IMessageBus(messageBus_);
    }

    /// @inheritdoc ICelerBase
    function setTrustedRemote(uint16 remoteChaindId_, bytes calldata remoteAddress_) external override onlyOwner {
        trustedRemoteLookup[remoteChaindId_] = remoteAddress_;
        emit LogSetTrustedRemote(remoteChaindId_, remoteAddress_);
    }

    /// @inheritdoc ICelerBase
    function getTrustedRemoteAddress(uint16 remoteChaindId_) external view override returns (bytes memory) {
        bytes memory path_ = trustedRemoteLookup[remoteChaindId_];
        if (path_.length == 0) revert RemoteChainNotTrustedError();
        return path_;
    }

    /// @inheritdoc ICelerBase
    function isTrustedRemote(uint16 remoteChaindId_, bytes calldata remoteAddress_)
        external
        view
        override
        returns (bool)
    {
        bytes memory trustedSource_ = trustedRemoteLookup[remoteChaindId_];
        return keccak256(trustedSource_) == keccak256(remoteAddress_);
    }
}
