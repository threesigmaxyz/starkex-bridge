// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface ILayerZeroSenderUserApplicationConfig {
    // @notice set the send() LayerZero messaging library version to _version
    // @param _version - new messaging library version
    function setSendVersion(uint16 _version) external;
}