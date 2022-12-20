// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibTokenRegister {

    bytes32 constant TOKEN_REGISTER_STORAGE_POSITION = keccak256("TOKEN_REGISTER_STORAGE_POSITION");

    struct TokenRegisterStorage {
        mapping(address => bool) registeredToken;
    }

    event LogSetTokenRegister(address token, bool flag);

    error TokenNotRegisteredError(address asset);

    function tokenRegisterStorage() internal pure returns (TokenRegisterStorage storage trs) {
        bytes32 position_ = TOKEN_REGISTER_STORAGE_POSITION;
        assembly {
            trs.slot := position_
        }
    }

	function setTokenRegister(
        address token_,
		bool flag_
    ) internal {
        tokenRegisterStorage().registeredToken[token_] = flag_;
        emit LogSetTokenRegister(token_, flag_);
    }

    function isTokenRegistered(address token_) internal view returns(bool) {
        return tokenRegisterStorage().registeredToken[token_];
    }

    function onlyRegisteredToken(address token_) internal view {
        if(!isTokenRegistered(token_)) revert TokenNotRegisteredError(token_);
    }
}