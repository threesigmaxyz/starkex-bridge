// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { IWormhole } from "src/dependencies/wormhole/interfaces/IWormhole.sol";
import { IWormholeReceptor } from "src/interfaces/interoperability/IWormholeReceptor.sol";
import { WormholeBase } from "src/interoperability/wormhole/WormholeBase.sol";

contract WormholeReceptor is IWormholeReceptor, WormholeBase {
    /// @notice Address of the _bridge.
    address private immutable _bridge;

    /// @notice Last nonce received. Useful to ignore outdated received roots.
    uint256 private _lastNonce;

    uint256 private _orderRoot;

    mapping(bytes32 => bool) public processedMessages;

    constructor(address wormholeBridge_, address relayer_, address bridge_) WormholeBase(wormholeBridge_, relayer_) {
        if (wormholeBridge_ == address(0)) revert ZeroWormholeAddressError();
        if (relayer_ == address(0)) revert ZeroRelayerAddressError();
        if (bridge_ == address(0)) revert ZeroBridgeAddressError();

        _bridge = bridge_;
        emit LogSetBridge(bridge_);
    }

    /// @notice Accepts the pending bridge role.
    function acceptBridgeRole() public override {
        IAccessControlFacet(_bridge).acceptRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);
        emit LogBridgeRoleAccepted();
    }

    /**
     * @notice The owner sets the root of the order tree.
     *         This adds another layer of security, stopping layerZero from sending any message.
     */
    function setOrderRoot() external override onlyOwner {
        uint256 orderRoot_ = _orderRoot;
        IStateFacet(_bridge).setOrderRoot(orderRoot_);
        emit LogOrderRootUpdate(orderRoot_);
    }

    /**
     * @notice Receives the root update.
     * @param whMessages_ Contains the root and the intended recipient.
     */
    function receiveWormholeMessages(bytes[] memory whMessages_, bytes[] memory) public payable override {
        // Function must be called only by the relayer for security.
        if (_msgSender() != address(relayer)) revert InvalidCallerError();

        (IWormhole.VM memory vm_, bool valid_, string memory reason_) = wormhole.parseAndVerifyVM(whMessages_[0]);

        // Ensure core contract verification succeeded.
        if (!valid_) revert VerificationFailError(reason_);

        // Ensure the emitterAddress of this VAA is a trusted address.
        if (bytes32(trustedRemoteLookup[vm_.emitterChainId]) != vm_.emitterAddress) revert InvalidEmitterError();

        // Replay protection.
        if (processedMessages[vm_.hash]) revert AlreadyProcessedError();
        processedMessages[vm_.hash] = true;

        (uint256 orderRoot_, bytes memory intendedRecipient_) = abi.decode(vm_.payload, (uint256, bytes));

        // Check that the contract which is processing this VAA is the intendedRecipient
        if (keccak256(intendedRecipient_) != keccak256(abi.encodePacked(address(this)))) {
            revert NotIntendedRecipientError();
        }

        _orderRoot = orderRoot_;
        emit LogRootReceived(orderRoot_);
    }
}
