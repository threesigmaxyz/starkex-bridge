// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { NonblockingLzReceiver } from "src/interoperability/lz/NonblockingLzReceiver.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { ILzReceptor } from "src/interfaces/interoperability/ILzReceptor.sol";
import { IMultiBridgeReceptor } from "src/interfaces/interoperability/IMultiBridgeReceptor.sol";

contract LzReceptor is ILzReceptor, NonblockingLzReceiver {
    /// @notice Last nonce received. Useful to ignore outdated received roots.
    uint256 private _lastNonce;

    /// @notice Address of the multiBridgeReceiver contract.
    address private _multiBridgeReceiver;

    constructor(address lzEndpoint_, address multiBridgeReceiver_) NonblockingLzReceiver(lzEndpoint_) {
        if (lzEndpoint_ == address(0)) revert ZeroLzEndpointAddressError();
        if (multiBridgeReceiver_ == address(0)) revert ZeroMultiBridgeAddressError();

        _multiBridgeReceiver = multiBridgeReceiver_;

        emit LogSetMultiBridgeAddress(multiBridgeReceiver_);
    }

    /// @inheritdoc ILzReceptor
    function setMultiBridgeAddress(address multiBridgeReceiver_) external override onlyOwner {
        if (multiBridgeReceiver_ == address(0)) revert ZeroMultiBridgeAddressError();

        _multiBridgeReceiver = multiBridgeReceiver_;

        emit LogSetMultiBridgeAddress(multiBridgeReceiver_);
    }

    /// @inheritdoc ILzReceptor
    function getMultiBridgeAddress() external view override returns (address) {
        return _multiBridgeReceiver;
    }

    /**
     * @notice Receives the root update and sends to the multiBridgeReceptor.
     * @param srcChainId_ The id of the source chain.
     * @param payload_ Contains the roots.
     */
    function _nonblockingLzReceive(uint16 srcChainId_, bytes memory, uint64, bytes memory payload_) internal override {
        emit LogRootReceived(payload_);

        IMultiBridgeReceptor(_multiBridgeReceiver).receiveRoot(payload_, srcChainId_);
    }
}
