// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AppStorage } from "src/storage/AppStorage.sol";

interface IDepositFacet {
	/**
     * @notice TODO
	 * @param lockHash TODO
     * @param starkKey TODO
     * @param asset TODO
     * @param amount TODO
     */
	event LogLockDeposit(uint256 indexed lockHash, uint256 indexed starkKey, address indexed asset, uint256 amount);

	/**
	 * @notice TODO
	 * @param lockHash TODO
	 * @param recipient TODO
	 */
	event LogClaimDeposit(uint256 indexed lockHash, address indexed recipient);

	/**
	 * @notice TODO
	 * @param lockHash TODO
	 */
	event LogReclaimDeposit(uint256 indexed lockHash);

	/// @notice TODO
	/// @param starkKey_ TODO
	/// @param asset_ TODO
	/// @param amount_ TODO
	/// @param lockHash_ TODO
	function lockDeposit(
		uint256 starkKey_,
		address asset_,
		uint256 amount_,
		uint256 lockHash_
	) external;

	/// @notice TODO
	/// @param lockHash_ TODO
	/// @param branchMask_ TODO
	/// @param proof_ TODO
	/// @param recipient_ TODO
	function claimDeposit(
		uint256 lockHash_,
		uint branchMask_,
		bytes32[] memory proof_,
		address recipient_
	) external;

	/// @notice TODO
	/// @param lockHash_ TODO
	function reclaimDeposit(uint256 lockHash_) external;

	/// @notice TODO
	/// @param hashId_ TODO
	function getDeposit(uint256 hashId_) external view returns (AppStorage.Deposit memory deposit_);

	/// @notice TODO
	/// @param asset_ TODO
    function getPendingDeposits(address asset_) external view returns (uint256 pending_);
}