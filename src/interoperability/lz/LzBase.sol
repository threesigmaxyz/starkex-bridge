// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { ILayerZeroEndpoint } from "src/dependencies/lz/interfaces/ILayerZeroEndpoint.sol";
import { ILzBase } from "src/interfaces/interoperability/lz/ILzBase.sol";
import { BytesLib } from "src/dependencies/lz/util/BytesLib.sol";

abstract contract LzBase is Ownable, ILzBase {
    using BytesLib for bytes;

    /// @notice The layerZero endpoint.
    ILayerZeroEndpoint public immutable lzEndpoint;

    /// @notice The trusted address in each remote chain.
    mapping(uint16 => bytes) public trustedRemoteLookup;

    /**
     * @notice Address of the precrime to add any extra security check.
     * @dev https://medium.com/layerzero-official/introducing-pre-crime-49bef4a581d5.
     */
    address public precrime;

    constructor(address _endpoint) {
        lzEndpoint = ILayerZeroEndpoint(_endpoint);
    }

    //---------------------------UserApplication config----------------------------------------

    /// @inheritdoc ILzBase
    function getConfig(uint16 version_, uint16 chaindId_, address, uint256 configType_)
        external
        view
        override
        returns (bytes memory)
    {
        return lzEndpoint.getConfig(version_, chaindId_, address(this), configType_);
    }

    /// @inheritdoc ILzBase
    function setConfig(uint16 version_, uint16 chaindId_, uint256 configType_, bytes calldata config_)
        external
        override
        onlyOwner
    {
        lzEndpoint.setConfig(version_, chaindId_, configType_, config_);
    }

    /// @inheritdoc ILzBase
    function setTrustedRemote(uint16 srcChaindId_, bytes calldata path_) external override onlyOwner {
        trustedRemoteLookup[srcChaindId_] = path_;
        emit LogSetTrustedRemote(srcChaindId_, path_);
    }

    /// @inheritdoc ILzBase
    function setTrustedRemoteAddress(uint16 remoteChaindId_, bytes calldata remoteAddress_)
        external
        override
        onlyOwner
    {
        trustedRemoteLookup[remoteChaindId_] = abi.encodePacked(remoteAddress_, address(this));
        emit LogSetTrustedRemoteAddress(remoteChaindId_, remoteAddress_);
    }

    /// @inheritdoc ILzBase
    function getTrustedRemoteAddress(uint16 remoteChaindId_) external view override returns (bytes memory) {
        bytes memory path = trustedRemoteLookup[remoteChaindId_];
        if (path.length == 0) revert RemoteChainNotTrustedError();
        return path.slice(0, path.length - 20); // the last 20 bytes should be address(this)
    }

    /// @inheritdoc ILzBase
    function setPrecrime(address precrime_) external override onlyOwner {
        precrime = precrime_;
        emit LogSetPrecrime(precrime_);
    }

    /// @inheritdoc ILzBase
    function isTrustedRemote(uint16 srcChaindId_, bytes calldata path_) external view override returns (bool) {
        bytes memory trustedSource = trustedRemoteLookup[srcChaindId_];
        return keccak256(trustedSource) == keccak256(path_);
    }
}
