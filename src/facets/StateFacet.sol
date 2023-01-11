// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibState } from "src/libraries/LibState.sol";
import { OnlyInteroperabilityContract } from "src/modifiers/OnlyInteroperabilityContract.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";

contract StateFacet is OnlyInteroperabilityContract, IStateFacet {
    /// @inheritdoc IStateFacet
    function getOrderRoot() external view override returns (uint256 orderRoot_) {
        orderRoot_ = LibState.getOrderRoot();
    }

    /// @inheritdoc IStateFacet
    function setOrderRoot(uint256 orderRoot_) external override onlyInteroperabilityContract {
        LibState.setOrderRoot(orderRoot_);
    }
}
