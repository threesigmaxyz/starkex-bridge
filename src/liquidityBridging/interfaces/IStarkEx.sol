// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStarkEx {
    function depositERC20(
        // NOLINT external-function.
        uint256 starkKey,
        uint256 assetType,
        uint256 vaultId,
        uint256 quantizedAmount
    ) external;

    /*
      Registers a new asset to the system.
      Once added, it can not be removed and there is a limited number
      of slots available.
    */
    function registerToken(uint256 assetType, bytes calldata assetInfo, uint256 quantum) external;
}
