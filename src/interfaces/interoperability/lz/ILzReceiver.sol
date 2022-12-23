// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILzReceiver {
    error InvalidEndpointCallerError();

    // @notice LayerZero endpoint will invoke this function to deliver the message on the destination
    // @param srcChaindId_ - the source endpoint identifier
    // @param path_ - the source sending contract address from the source chain
    // @param nonce_ - the ordered message nonce
    // @param payload_ - the signed payload is the UA bytes has encoded to be sent
    function lzReceive(uint16 srcChaindId_, bytes calldata path_, uint64 nonce_, bytes calldata payload_) external;

    /**
     * @notice Sets the version of the receive.
     * @param version_ The version.
     */
    function setReceiveVersion(uint16 version_) external;

    /**
     * @notice If the app is in blocking mode, this function forcefully receives next messages.
     * @param srcChaindId_ The id of the source chain.
     * @param path_ The trusted path.
     */
    function forceResumeReceive(uint16 srcChaindId_, bytes calldata path_) external;
}
