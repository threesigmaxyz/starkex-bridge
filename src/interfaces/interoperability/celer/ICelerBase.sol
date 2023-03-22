// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICelerBase {
    /**
     * @notice Emitted when a trusted remote is set.
     * @param remoteChainId The id of the remote chain.
     * @param path The encoded path - remote address and local address.
     */
    event LogSetTrustedRemote(uint16 indexed remoteChainId, bytes indexed path);

    error RemoteChainNotTrustedError();

    /**
     * @notice Sets a trusted remote address for the cross-chain communication.
     * @param remoteChaindId_ The id of the remote chain.
     * @param remoteAddress_ The address of the remote address, in bytes.
     */
    function setTrustedRemote(uint16 remoteChaindId_, bytes calldata remoteAddress_) external;

    /**
     * @notice Gets the remote address of a remote chain.
     * @param remoteChaindId_ The id of the remote chain.
     */
    function getTrustedRemoteAddress(uint16 remoteChaindId_) external view returns (bytes memory);

    /**
     * @notice Checks if a source chainId and a source address are trusted.
     * @param remoteChaindId_ The id of the remote chain.
     * @param remoteAddress_ The address of the remote address, in bytes to check.
     */
    function isTrustedRemote(uint16 remoteChaindId_, bytes calldata remoteAddress_) external view returns (bool);
}
