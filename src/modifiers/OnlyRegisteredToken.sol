// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";

abstract contract OnlyRegisteredToken {
    modifier onlyRegisteredToken(address token_) {
        LibTokenRegister.onlyRegisteredToken(token_);
        _;
    }
}