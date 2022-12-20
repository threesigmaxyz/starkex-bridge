// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface ITokenRegisterFacet {
    
    struct TokenRegisterStorage {
        mapping(address => bool) registeredTokens;
    }

    /**
     * TODO
     */
    event LogSetTokenRegister(address token, bool flag);

    /**
     * TODO
     */
    function setTokenRegister(address token_, bool flag_) external;

    function isTokenRegistered(address token_) external returns(bool);
}