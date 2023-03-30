// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMultiBridgeReceptor {
    struct MsgChecks {
        uint32 weight; // Weight the message has accumulated.
        mapping(address => bool) repeated; // Checks if a bridge has already sent this message.
    }

    /**
     * @notice Emitted when the bridge address is set.
     * @param bridge The bridge address.
     */
    event LogSetBridge(address indexed bridge);

    /**
     * @notice Emitted when the order root of the bridge is updated.
     * @param orderRoot The order root.
     */
    event LogOrderRootUpdate(uint256 indexed orderRoot);

    /// @notice Emitted when the interoperability role in the bridge is accepted.
    event LogBridgeRoleAccepted();

    /**
     * @notice Emitted when an order root message is received.
     * @param srcChainId The chain the root comes from.
     * @param bridgeReceiver The address of the bridge.
     * @param orderRoot The order root.
     */
    event LogRootSigleMsgReceived(uint16 indexed srcChainId, address indexed bridgeReceiver, uint256 indexed orderRoot);

    /**
     * @notice Emitted when an order root message is executed.
     * @param orderRoot The order root of the executed message.
     * @param sequenceNumber The sequenceNumber of the executed message.
     */
    event LogRootMsgExecuted(uint256 indexed orderRoot, uint256 indexed sequenceNumber);

    /**
     * @notice Emitted when the threshold is updated.
     * @param threshold The new threshold.
     */
    event LogThresholdUpdated(uint64 indexed threshold);

    /**
     * @notice Emitted when the weight of a bridge is updated.
     * @param bridge Address of bridge updated.
     * @param newWeight Weight updated.
     */
    event LogUpdatedBridgeWeight(address indexed bridge, uint32 indexed newWeight);

    /**
     * @notice Emitted when an outdated message is received.
     * @param srcChainId The chain the root comes from.
     * @param orderRoot The order root.
     * @param sequenceNumber The outdated sequenceNumber.
     */
    event LogOutdatedRootReceived(uint16 indexed srcChainId, uint256 indexed orderRoot, uint256 indexed sequenceNumber);

    error InvalidThresholdError();
    error ZeroBridgeAddressError();
    error NotAllowedBridgeError();
    error AlreadyReceivedFromBridgeError();

    /// @notice Accepts the pending bridge role.
    function acceptBridgeRole() external;

    /**
     * @notice The owner sets the root of the order tree.
     *         This adds another layer of security, stopping the receiver from sending any message.
     */
    function setOrderRoot() external;

    /**
     * @notice Called by a bridge when a message is received, message is only executed if enought bridges have delivered the same message.
     * @param payload_ The payload received.
     * @param srcChainId_ The source chain identifier.
     */
    function receiveRoot(bytes memory payload_, uint16 srcChainId_) external;

    /**
     * @notice Updates the threshold to execute a message.
     * @param threshold_ The new threshold.
     */
    function updateThreshold(uint64 threshold_) external;

    /**
     * @notice Updates the weight of a bridge, if put at zero essentialy removes the bridge.
     * @param bridge_ Address of bridge to update.
     * @param newWeight_ Weight to update.
     */
    function updateBridgeWeight(address bridge_, uint32 newWeight_) external;

    /**
     * @notice Calculate the message id.
     * @param orderRoot_ The order root.
     * @param srcChainId_ The source chain identifier.
     */
    function getMsgId(uint256 orderRoot_, uint16 srcChainId_) external pure returns (bytes32);

    /**
     * @notice Gets current threshold.
     * @return Current threshold.
     */
    function getThreshold() external view returns (uint64);

    /**
     * @notice Gets total bridge weight.
     * @return total bridge weight.
     */
    function getTotalWeight() external view returns (uint64);

    /**
     * @notice Gets the weight of a bridge.
     * @param bridge_ Address of the bridge.
     * @return Weight of the bridge.
     */
    function getBridgesWeight(address bridge_) external view returns (uint32);

    /**
     * @notice Gets the weight of a message.
     * @param msgId_ Id of the message.
     * @return Weight of the message.
     */
    function getMsgWeight(bytes32 msgId_) external view returns (uint32);
}
