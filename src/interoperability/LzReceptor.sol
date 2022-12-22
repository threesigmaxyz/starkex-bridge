// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Pausable } from "@openzeppelin/security/Pausable.sol";
import { NonblockingLzReceiver } from "src/dependencies/lz/NonblockingLzReceiver.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

interface IBridge {
    function setOrderRoot(uint256 orderRoot_) external;
    function acceptRole(bytes32 role_) external;
}

contract LzReceptor is NonblockingLzReceiver, Pausable {
    
    IBridge immutable private _bridge;
    uint256 _lastNonce;

    error ZeroBridgeAddressError();
    error ZeroLzEndpointAddressError();

    event LogOutdatedRootReceived(uint256 orderRoot, uint64 nonce);
    event LogOrderRootUpdate(uint256 orderRoot);
    event LogBridgeRoleAccepted();
    event LogBridgeSet(address bridge);

    constructor(
        address lzEndpoint_,
        address bridgeAddress_
    ) NonblockingLzReceiver(lzEndpoint_) {
        if (lzEndpoint_ == address(0)) revert ZeroLzEndpointAddressError();
        if (bridgeAddress_ == address(0)) revert ZeroBridgeAddressError();

        _bridge = IBridge(bridgeAddress_);

        emit LogBridgeSet(bridgeAddress_);
    }

    /**
     * @notice Accepts the pending bridge role.
     */
    function acceptBridgeRole() public {
        _bridge.acceptRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);
        emit LogBridgeRoleAccepted();
    }

    /**
     * @notice Receives the root update.
     * @param srcChainId_ The source chain Id.
     * @param srcAddress_ The source address that sent the message.
     * @param nonce_ The nonce of the message.
     * @param payload_ Contains the roots.  
     */
    function _nonblockingLzReceive(
        uint16 srcChainId_,
        bytes memory srcAddress_,
        uint64 nonce_,
        bytes memory payload_
    ) internal override {
        (uint256 orderRoot_) = abi.decode(payload_, (uint256));

        /// @dev No revert because the most recent order tree contains all the old info.
        if (nonce_ <= _lastNonce) {
            emit LogOutdatedRootReceived(orderRoot_, nonce_);
            return;
        }
        _lastNonce = nonce_;

        _bridge.setOrderRoot(orderRoot_);

        emit LogOrderRootUpdate(orderRoot_);
    }
}