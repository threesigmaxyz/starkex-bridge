// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Modifiers }     from "src/Modifiers.sol";
import { IStateFacet } from "src/interfaces/IStateFacet.sol";
import { AppStorage }    from "src/storage/AppStorage.sol";

contract StateFacet is Modifiers, IStateFacet {

    AppStorage.AppStorage s;

    function getOrderRoot() external view override returns (uint256 orderRoot_) {
        orderRoot_ = s.orderRoot;
    }

    function setOrderRoot(uint256 orderRoot_) external override onlyInteroperabilityContract {
        s.orderRoot = orderRoot_;
    }
}