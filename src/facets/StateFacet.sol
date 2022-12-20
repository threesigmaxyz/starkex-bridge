// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibState }    from "src/libraries/LibState.sol";
import { OnlyInteroperabilityContract } from "src/modifiers/OnlyInteroperabilityContract.sol";
import { IStateFacet } from "src/interfaces/IStateFacet.sol";

contract StateFacet is OnlyInteroperabilityContract, IStateFacet {

    function getOrderRoot() external view override returns (uint256 orderRoot_) {
        orderRoot_ = LibState.stateStorage().orderRoot;
    }

    function setOrderRoot(uint256 orderRoot_) external override onlyInteroperabilityContract {
        LibState.stateStorage().orderRoot = orderRoot_;
        emit LogSetOrderRoot(orderRoot_);
    }
}