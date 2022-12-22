// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILzReceptor {

    error ZeroBridgeAddressError();
    error ZeroLzEndpointAddressError();

    event LogOutdatedRootReceived(uint256 orderRoot, uint64 nonce);
    event LogOrderRootUpdate(uint256 orderRoot);
    event LogBridgeRoleAccepted();
    event LogBridgeSet(address bridge);

    /**
     * @notice Accepts the pending bridge role.
     */
    function acceptBridgeRole() external;
}