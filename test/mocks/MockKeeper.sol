//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockKeeper {
    fallback() external payable {
        revert();
    }
}
