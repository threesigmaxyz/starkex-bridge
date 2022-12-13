// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AppStorage {
    /// @notice TODO
    struct Deposit {
        address receiver;   // TODO rename (fallback receiver)
        uint256 starkKey;
        address asset;
        uint256 amount;
        uint256 expirationDate;
    }

    /// @notice TODO
    struct Withdrawal {
        uint256 starkKey;
        address asset;
        uint256 amount;
        uint256 expirationDate;
    }

    struct AppStorage {
        address starkexOperatorAddress;
        address l1SetterAddress;

        // Order Tree Root & Height.
        uint256 orderRoot;
        
        // Deposit variables
        uint256 depositNonce;
        mapping(uint256 => Deposit) deposits;
        mapping(address => uint256) pendingDeposits;	/// TODO what is the purpose of this var?

        // Withdraw variables
        mapping(uint256 => Withdrawal) withdrawals;
        mapping(address => uint256) pendingWithdrawals;	/// TODO what is the purpose of this var?

        // Access control variables
        mapping(address => bool) tokenAdmins;

        // Token register variables
        mapping(uint256 => bool) registeredAssetType;
        mapping(uint256 => bytes) assetTypeToAssetInfo;
        mapping(uint256 => uint256) assetTypeToQuantum;

        // LayerZero variables
        mapping(address => uint) lzRemoteMessageCounter;
        uint256 lzMessageCounter;	// TODO can merge this two variable into one lzRemoteMessageCounter[msg.sender]   
    }
}
