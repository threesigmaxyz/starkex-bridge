// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILzBase {

    /**
    * @notice Emitted when a new precrime address is set.
    * @param precrime The address of the precrime.
    */
    event LogSetPrecrime(address precrime);

    /**
     * @notice Emitted when a trusted remote is set.
     * @param remoteChainId The id of the remote chain.
     * @param path The encoded path - remote address and local address.
     */
    event LogSetTrustedRemote(uint16 remoteChainId, bytes path);

    /**
     * @notice Emitted when a trusted remote address is set.
     * @param remoteChainId The id of the remote chain.
     * @param remoteAddress The remote address, in bytes.
     */
    event LogSetTrustedRemoteAddress(uint16 remoteChainId, bytes remoteAddress);

    error RemoteChainNotTrustedError();

    // @notice set the configuration of the LayerZero messaging library of the specified version
    // @param version_ - messaging library version
    // @param chaindId_ - the chainId for the pending config change
    // @param configType_ - type of configuration. every messaging library has its own convention.
    // @param config_ - configuration in the bytes. can encode arbitrary content.
    function setConfig(uint16 version_, uint16 chaindId_, uint configType_, bytes calldata config_) external;

    /**
     * @notice Gets the current configuration.
     * @param version_ The version.
     * @param chaindId_ The id of the chain.
     * @param configType_ The type of configuration.
     */
    function getConfig(uint16 version_, uint16 chaindId_, address, uint configType_) external view returns (bytes memory);

    /**
     * @notice Sets a trusted remote address for the cross-chain communication.
     * @param srcChaindId_ The id of the source chain.
     * @param path_ The path `abi.encodePacked(remoteAddress, localAddress)`.
     */
    function setTrustedRemote(uint16 srcChaindId_, bytes calldata path_) external;

    /**
     * @notice Similar to `setTrustedRemote`, but the local address is enforced to be this.
     * @param remoteChaindId_ The id of the remote chain.
     * @param remoteAddress_ The address of the remote address, in bytes.
     */
    function setTrustedRemoteAddress(uint16 remoteChaindId_, bytes calldata remoteAddress_) external;
    
    /**
     * @notice Gets the remote address of a remote chain.
     * @param remoteChaindId_ The id of the remote chain.
     */
    function getTrustedRemoteAddress(uint16 remoteChaindId_) external view returns (bytes memory);

    /**
     * @notice Sets the precrime address.
     * @dev Adds additional safety checks if specified.
     * @param precrime_ The address of the precrime.
     */
    function setPrecrime(address precrime_) external;

    /**
     * @notice Checks if a source chainId and a source address are trusted.
     * @param srcChaindId_ The id of the remote chain.
     * @param path_ The path `abi.encodePacked(remoteAddress, localAddress)` to check.
     */
    function isTrustedRemote(uint16 srcChaindId_, bytes calldata path_) external view returns (bool);
}