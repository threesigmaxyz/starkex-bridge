// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Pausable }              from "@openzeppelin/security/Pausable.sol";
import { NonblockingLzReceiver } from "src/dependencies/lz/NonblockingLzReceiver.sol";
import { LibAccessControl  }     from "src/libraries/LibAccessControl.sol";
import { IAccessControlFacet }   from "src/interfaces/facets/IAccessControlFacet.sol";
import { IStateFacet }           from "src/interfaces/facets/IStateFacet.sol";
import { ILzReceptor }           from "src/interfaces/interoperability/ILzReceptor.sol";

contract LzReceptor is ILzReceptor, NonblockingLzReceiver, Pausable {
    
    address immutable private _bridge;
    uint256 private _lastNonce;

    constructor(
        address lzEndpoint_,
        address bridgeAddress_
    ) NonblockingLzReceiver(lzEndpoint_) {
        if (lzEndpoint_ == address(0)) revert ZeroLzEndpointAddressError();
        if (bridgeAddress_ == address(0)) revert ZeroBridgeAddressError();

        _bridge = bridgeAddress_;

        emit LogBridgeSet(bridgeAddress_);
    }

    /// @inheritdoc ILzReceptor
    function acceptBridgeRole() public override {
        IAccessControlFacet(_bridge).acceptRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);
        emit LogBridgeRoleAccepted();
    }

    /**
     * @notice Receives the root update.
     * @param nonce_ The nonce of the message.
     * @param payload_ Contains the roots.  
     */
    function _nonblockingLzReceive(
        uint16,
        bytes memory,
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

        IStateFacet(_bridge).setOrderRoot(orderRoot_);

        emit LogOrderRootUpdate(orderRoot_);
    }
}