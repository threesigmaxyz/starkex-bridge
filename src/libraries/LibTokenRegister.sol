// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibTokenRegister {

    bytes32 constant TOKEN_REGISTER_STORAGE_POSITION = keccak256("TOKEN_REGISTER_STORAGE_POSITION");

    struct TokenRegisterStorage {
        mapping(address => bool) tokenAdmins;
        mapping(uint256 => bool) registeredAssetType;
        mapping(uint256 => bytes) assetTypeToAssetInfo;
        mapping(uint256 => uint256) assetTypeToQuantum;

        mapping(address => bool) registeredToken;
    }

    function tokenRegisterStorage() internal pure returns (TokenRegisterStorage storage fs) {
        bytes32 position_ = TOKEN_REGISTER_STORAGE_POSITION;
        assembly {
            fs.slot := position_
        }
    }

    function isTokenAdmin(address admin_) internal view returns (bool) {
        return tokenRegisterStorage().tokenAdmins[admin_];
    }

    // TODO deprecated for 'isTokenRegistered'
    function isAssetRegistered(uint256 assetType_) internal view returns (bool) {
        return tokenRegisterStorage().registeredAssetType[assetType_];
    }

    function isTokenRegistered(address token_) internal view returns (bool) {
        return tokenRegisterStorage().registeredToken[token_];
    }
}