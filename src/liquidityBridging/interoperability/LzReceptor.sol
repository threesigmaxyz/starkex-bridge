// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { NonblockingLzReceiver } from "src/interoperability/lz/NonblockingLzReceiver.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { ILzReceptor } from "src/liquidityBridging/interfaces/ILzReceptor.sol";
import { ILiquidityBridge } from "src/liquidityBridging/interfaces/ILiquidityBridge.sol";

contract LzReceptor is ILzReceptor, NonblockingLzReceiver {
    /// @notice Address of the _bridge.
    address private immutable _bridge;

    /// @notice Address of the liquidity bridge contract.
    address private _liquidityBridge;

    constructor(address lzEndpoint_, address bridge_, address liquidityBridge_) NonblockingLzReceiver(lzEndpoint_) {
        if (lzEndpoint_ == address(0)) revert ZeroLzEndpointAddressError();
        if (bridge_ == address(0)) revert ZeroBridgeAddressError();
        if (liquidityBridge_ == address(0)) revert ZeroBridgeAddressError();

        _liquidityBridge = liquidityBridge_;
        _bridge = bridge_;

        emit LogSetLiquidityBridge(liquidityBridge_);
        emit LogSetBridge(bridge_);
    }

    /// @inheritdoc ILzReceptor
    function acceptBridgeRole() public override {
        IAccessControlFacet(_bridge).acceptRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);
        emit LogBridgeRoleAccepted();
    }

    /// @inheritdoc ILzReceptor
    function setLiquidityBridge(address liquidityBridge_) external override onlyOwner {
        _liquidityBridge = liquidityBridge_;
        emit LogSetLiquidityBridge(liquidityBridge_);
    }

    /**
     * @notice Receives the root update.
     * @param srcChainId_ The Id of the source chain.
     * @param payload_ Contains the info to make deposit.
     */
    function _nonblockingLzReceive(uint16 srcChainId_, bytes memory, uint64, bytes memory payload_) internal override {
        (uint256 starkKey_, uint256 vaultId_, address token_, uint256 amount_) =
            abi.decode(payload_, (uint256, uint256, address, uint256));

        ILiquidityBridge(_liquidityBridge).mintAndDepositStarkEx(srcChainId_, starkKey_, vaultId_, token_, amount_);
        emit LogMintDepositStarkEx(srcChainId_, starkKey_, vaultId_, token_, amount_);
    }
}
