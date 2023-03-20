// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { IMessageBus } from "src/dependencies/celer/interfaces/IMessageBus.sol";
import { ICelerReceptor } from "src/interfaces/interoperability/ICelerReceptor.sol";
import { CelerBase } from "src/interoperability/celer/CelerBase.sol";

contract CelerReceptor is ICelerReceptor, CelerBase {
    /// @notice Address of the _bridge.
    address private immutable _bridge;

    /// @notice Last nonce received. Useful to ignore outdated received roots.
    uint256 private _lastNonce;

    uint256 private _orderRoot;

    mapping(bytes32 => bool) public processedMessages;

    constructor(address messageBus_, address bridge_) CelerBase(messageBus_) {
        if (messageBus_ == address(0)) revert ZeroCelerAddressError();
        if (bridge_ == address(0)) revert ZeroBridgeAddressError();

        _bridge = bridge_;
        emit LogSetBridge(bridge_);
    }

    /// @inheritdoc ICelerReceptor
    function acceptBridgeRole() public override {
        IAccessControlFacet(_bridge).acceptRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);
        emit LogBridgeRoleAccepted();
    }

    /// @inheritdoc ICelerReceptor
    function setOrderRoot() external override onlyOwner {
        uint256 orderRoot_ = _orderRoot;
        IStateFacet(_bridge).setOrderRoot(orderRoot_);
        emit LogOrderRootUpdate(orderRoot_);
    }

    /// @inheritdoc ICelerReceptor
    function executeMessage(address emitterAddress_, uint64 emitterChainId_, bytes calldata message_, address)
        public
        payable
        override
        returns (ExecutionStatus)
    {
        // Function must be called only by the relayer for security.
        if (_msgSender() != address(messageBus)) revert InvalidCallerError();

        // Ensure the emitterAddress of this is a trusted address.
        bytes memory trustedRemote_ = trustedRemoteLookup[uint16(emitterChainId_)];
        if (keccak256(trustedRemote_) != keccak256(abi.encodePacked(emitterAddress_))) revert InvalidEmitterError();

        (uint256 orderRoot_, bytes memory intendedRecipient_) = abi.decode(message_, (uint256, bytes));

        // Check that the contract which is processing is the intendedRecipient
        if (keccak256(intendedRecipient_) != keccak256(abi.encodePacked(address(this)))) {
            revert NotIntendedRecipientError();
        }

        _orderRoot = orderRoot_;
        emit LogRootReceived(orderRoot_);

        return ExecutionStatus.Success;
    }
}
