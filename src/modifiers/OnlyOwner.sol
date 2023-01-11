// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

abstract contract OnlyOwner {
    modifier onlyOwner() {
        LibAccessControl.onlyRole(LibAccessControl.OWNER_ROLE);
        _;
    }
}
