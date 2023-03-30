// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable2Step } from "@openzeppelin/access/Ownable2Step.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { IMultiBridgeReceptor } from "src/interfaces/interoperability/IMultiBridgeReceptor.sol";

contract MultiBridgeReceptor is IMultiBridgeReceptor, Ownable2Step {
    uint256 private constant THRESHOLD_DECIMAL = 100;

    /// @notice Percentage (0-100) of _totalWeight needed for a message to execute.
    uint64 private _threshold;

    /// @notice Mapping with the bridge receptors and their weight.
    mapping(address => uint32) private _bridgesWeight;

    /// @notice Total weight of all bridges.
    uint64 private _totalWeight;

    /// @notice Mapping with the id of a message and their security checks.
    mapping(bytes32 => MsgChecks) private _msgInfo;

    /// @notice Address of the _bridge.
    address private immutable _bridge;

    /// @notice Order root to be updated.
    uint256 private _orderRoot;

    /// @notice Last sequenceNumber received and executed. Useful to ignore outdated received roots.
    uint256 private _lastSequenceNumber;

    constructor(address bridge_) {
        if (bridge_ == address(0)) revert ZeroBridgeAddressError();

        _bridge = bridge_;

        emit LogSetBridge(bridge_);
    }

    /// @inheritdoc IMultiBridgeReceptor
    function receiveRoot(bytes memory payload_, uint16 srcChainId_) external override {
        if (_bridgesWeight[msg.sender] == 0) revert NotAllowedBridgeError();

        //  Decode payload.
        (bytes memory orderRootE_, uint256 sequenceNumber_) = abi.decode(payload_, (bytes, uint256));
        uint256 orderRoot_ = abi.decode(orderRootE_, (uint256));

        //  Create msgId.
        bytes32 msgId_ = getMsgId(orderRoot_, srcChainId_);

        MsgChecks storage msgInfo_ = _msgInfo[msgId_];

        //  Check if message already received.
        if (msgInfo_.repeated[msg.sender] == true) revert AlreadyReceivedFromBridgeError();
        msgInfo_.repeated[msg.sender] = true;

        //  Return because the most recent order tree contains all the old info.
        //  Also checks if message already executed.
        if (sequenceNumber_ <= _lastSequenceNumber) {
            emit LogOutdatedRootReceived(srcChainId_, orderRoot_, sequenceNumber_);
            return;
        }

        emit LogRootSigleMsgReceived(srcChainId_, msg.sender, orderRoot_);

        msgInfo_.weight += _bridgesWeight[msg.sender];

        //  If enought weight behind message execute.
        if (msgInfo_.weight >= (_totalWeight * _threshold) / THRESHOLD_DECIMAL) {
            _lastSequenceNumber = sequenceNumber_;
            _orderRoot = orderRoot_;
            emit LogRootMsgExecuted(orderRoot_, sequenceNumber_);
        }
    }

    /// @inheritdoc IMultiBridgeReceptor
    function acceptBridgeRole() public override {
        IAccessControlFacet(_bridge).acceptRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);
        emit LogBridgeRoleAccepted();
    }

    /// @inheritdoc IMultiBridgeReceptor
    function setOrderRoot() external override onlyOwner {
        uint256 orderRoot_ = _orderRoot;
        IStateFacet(_bridge).setOrderRoot(orderRoot_);
        emit LogOrderRootUpdate(orderRoot_);
    }

    /// @inheritdoc IMultiBridgeReceptor
    function updateThreshold(uint64 threshold_) external override onlyOwner {
        if (threshold_ > THRESHOLD_DECIMAL) revert InvalidThresholdError();
        _threshold = threshold_;
        emit LogThresholdUpdated(threshold_);
    }

    /// @inheritdoc IMultiBridgeReceptor
    function updateBridgeWeight(address bridge_, uint32 newWeight_) external override onlyOwner {
        if (_bridgesWeight[bridge_] == 0) {
            _totalWeight += newWeight_;
        } else {
            _totalWeight -= _bridgesWeight[bridge_];
            _totalWeight += newWeight_;
        }

        _bridgesWeight[bridge_] = newWeight_;

        emit LogUpdatedBridgeWeight(bridge_, newWeight_);
    }

    /// @inheritdoc IMultiBridgeReceptor
    function getMsgId(uint256 orderRoot_, uint16 srcChainId_) public pure override returns (bytes32) {
        return keccak256(abi.encodePacked(orderRoot_, srcChainId_));
    }

    /// @inheritdoc IMultiBridgeReceptor
    function getThreshold() external view override returns (uint64) {
        return _threshold;
    }

    /// @inheritdoc IMultiBridgeReceptor
    function getTotalWeight() external view override returns (uint64) {
        return _totalWeight;
    }

    /// @inheritdoc IMultiBridgeReceptor
    function getBridgesWeight(address bridge_) external view override returns (uint32) {
        return _bridgesWeight[bridge_];
    }

    /// @inheritdoc IMultiBridgeReceptor
    function getMsgWeight(bytes32 msgId_) external view override returns (uint32) {
        return _msgInfo[msgId_].weight;
    }
}
