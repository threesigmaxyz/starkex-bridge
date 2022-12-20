// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface ITokenRegisterFacet {

    struct TokenRegisterStorage {
        mapping(address => bool) registeredTokens;
    }

    /**
     * @notice Emits the change in a token register.
     * @param token The address of the token.
     * @param flag Boolean that registers or ungisters the token. 
     */
    event LogSetTokenRegister(address token, bool flag);

    /**
     * @notice Registers or unregisters a token.
     * @param token_ The address of the token.
     * @param flag_ Boolean that registers or ungisters the token. 
     */
    function setTokenRegister(address token_, bool flag_) external;

    /**
     * @notice Checks if a token is registered.
     * @param token_ The address of the token.
     * @return Returns true if the token is registered; false otherwise.
     */
    function isTokenRegistered(address token_) external returns(bool);
}