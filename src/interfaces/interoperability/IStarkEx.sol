// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStarkEx {
    /// @notice Gets the root of the order tree from the starkEx contract.
    function getOrderRoot() external view returns (uint256);

    /// @notice Gets the sequence number of the roots in the starkEx contract.
    function getSequenceNumber() external view returns (uint256);
}