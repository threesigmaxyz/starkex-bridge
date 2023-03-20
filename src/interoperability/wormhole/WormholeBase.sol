// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { IWormholeBase } from "src/interfaces/interoperability/wormhole/IWormholeBase.sol";
import { IWormhole } from "src/dependencies/wormhole/interfaces/IWormhole.sol";
import { ICoreRelayer } from "src/dependencies/wormhole/interfaces/ICoreRelayer.sol";

abstract contract WormholeBase is IWormholeBase, Ownable {
    /// @notice The trusted address in each remote chain.
    mapping(uint16 => bytes) public trustedRemoteLookup;

    /// @notice The wormhole core address.
    IWormhole public immutable wormhole;

    /// @notice The wormhole relayer address.
    ICoreRelayer public immutable relayer;

    constructor(address wormholeBridge_, address relayer_) {
        wormhole = IWormhole(wormholeBridge_);
        relayer = ICoreRelayer(relayer_);
    }

    /// @inheritdoc IWormholeBase
    function setTrustedRemote(uint16 remoteChaindId_, bytes calldata remoteAddress_) external override onlyOwner {
        trustedRemoteLookup[remoteChaindId_] = remoteAddress_;
        emit LogSetTrustedRemote(remoteChaindId_, remoteAddress_);
    }

    /// @inheritdoc IWormholeBase
    function getTrustedRemoteAddress(uint16 remoteChaindId_) external view override returns (bytes memory) {
        bytes memory path_ = trustedRemoteLookup[remoteChaindId_];
        if (path_.length == 0) revert RemoteChainNotTrustedError();
        return path_;
    }

    /// @inheritdoc IWormholeBase
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
