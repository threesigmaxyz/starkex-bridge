// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStateFacet {

    /**
     * @notice Emits a new order root change.
     * @param orderRoot The order root.
     */
    event LogSetOrderRoot(uint256 orderRoot);

    /**
     * @notice Returns the current order root.
     * @return orderRoot_ The order root. 
     */
    function getOrderRoot() external view returns (uint256 orderRoot_);

    /**
     * @notice Sets the order root (only the interoperability contract).
     * @param orderRoot_ The order root.
     */
    function setOrderRoot(uint256 orderRoot_) external;
}