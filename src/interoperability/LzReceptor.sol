// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Pausable } from "@openzeppelin/security/Pausable.sol";
import { NonblockingLzReceiver } from "src/interoperability/lz/NonblockingLzReceiver.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { ILzReceptor } from "src/interfaces/interoperability/ILzReceptor.sol";

contract LzReceptor is ILzReceptor, NonblockingLzReceiver, Pausable {
    /// @notice Address of the _bridge.
    address private immutable _bridge;

    /// @notice Last nonce received. Useful to ignore outdated received roots.
    uint256 private _lastNonce;

    uint256 private _orderRoot;

    constructor(address lzEndpoint_, address bridge_) NonblockingLzReceiver(lzEndpoint_) {
        if (lzEndpoint_ == address(0)) revert ZeroLzEndpointAddressError();
        if (bridge_ == address(0)) revert ZeroBridgeAddressError();

        _bridge = bridge_;
        emit LogSetBridge(bridge_);
    }

    /// @inheritdoc ILzReceptor
    function acceptBridgeRole() public override {
        IAccessControlFacet(_bridge).acceptRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);
        emit LogBridgeRoleAccepted();
    }

    /// @inheritdoc ILzReceptor
    function setOrderRoot() external override onlyOwner {
        uint256 orderRoot_ = _orderRoot;
        IStateFacet(_bridge).setOrderRoot(orderRoot_);
        emit LogOrderRootUpdate(orderRoot_);
    }

    /**
     * @notice Receives the root update.
     * @param nonce_ The nonce of the message.
     * @param payload_ Contains the roots.
     */
    function _nonblockingLzReceive(uint16, bytes memory, uint64 nonce_, bytes memory payload_) internal override {
        (uint256 orderRoot_) = abi.decode(payload_, (uint256));

        /// Return because the most recent order tree contains all the old info.
        if (nonce_ <= _lastNonce) {
            emit LogOutdatedRootReceived(orderRoot_, nonce_);
            return;
        }
        _lastNonce = nonce_;

        _orderRoot = orderRoot_;
        emit LogRootReceived(orderRoot_);
    }
}
