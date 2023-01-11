// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

abstract contract OnlyInteroperabilityContract {
    modifier onlyInteroperabilityContract() {
        LibAccessControl.onlyRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);
        _;
    }
}
