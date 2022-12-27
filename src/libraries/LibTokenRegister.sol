// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibTokenRegister {
    bytes32 constant TOKEN_REGISTER_STORAGE_POSITION = keccak256("TOKEN_REGISTER_STORAGE_POSITION");

    struct TokenRegisterStorage {
        mapping(address => bool) registeredToken;
    }

    /**
     * @notice Emitted when a token is registered or unregistered.
     * @param token Address of the token to register.
     * @param flag Whether to register or unregister.
     */
    event LogSetTokenRegister(address indexed token, bool indexed flag);

    error TokenNotRegisteredError(address asset);

    /// @dev Storage of this facet using diamond storage.
    function tokenRegisterStorage() internal pure returns (TokenRegisterStorage storage trs) {
        bytes32 position_ = TOKEN_REGISTER_STORAGE_POSITION;
        assembly {
            trs.slot := position_
        }
    }

    /**
     * @notice Registers or unregisters a token.
     * @param token_ The address of the token to set the register.
     * @param flag_ Whether to register or unregister.
     */
    function setTokenRegister(address token_, bool flag_) internal {
        tokenRegisterStorage().registeredToken[token_] = flag_;
        emit LogSetTokenRegister(token_, flag_);
    }

    /**
     * @notice Checks if a token is registered.
     * @param token_ The address of the token.
     * @return Whether it is registered or not.
     */
    function isTokenRegistered(address token_) internal view returns (bool) {
        return tokenRegisterStorage().registeredToken[token_];
    }

    /**
     * @notice Modifier helper to be called from "src/modifiers".
     * @dev Reverts if not registered.
     * @param token_ Address of the token to check.
     */
    function onlyRegisteredToken(address token_) internal view {
        if (!isTokenRegistered(token_)) revert TokenNotRegisteredError(token_);
    }
}
