// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

abstract contract OnlyStarkExOperator {
    modifier onlyStarkExOperator() {
        LibAccessControl.onlyRole(LibAccessControl.STARKEX_OPERATOR_ROLE);
        _;
    }
}
