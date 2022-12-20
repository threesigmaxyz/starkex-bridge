// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

abstract contract OnlyTokenAdmin {
    modifier onlyTokenAdmin {
        LibAccessControl.onlyRole(LibAccessControl.TOKEN_ADMIN_ROLE);
        _;
    }
}