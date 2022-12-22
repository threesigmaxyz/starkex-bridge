// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStarkEx {
    function getOrderRoot() external view returns (uint256);
    function getSequenceNumber() external view returns (uint256);
}