// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWrappedTokenFactory {
    /**
     * @notice Emitted when a Wrapped Token is created.
     * @param quantum The StarkEx asset quantum.
     */
    event LogWrappedTokenCreated(uint256 indexed quantum);

    /**
     * @notice Used to create a wrapped token.
     * @param quantum_ The StarkEx asset quantum.
     * @return wrappedToken_ The address of the created token.
     */
    function createWrappedToken(uint16 srcChainId_, address token_, uint256 quantum_)
        external
        returns (address wrappedToken_);
}
