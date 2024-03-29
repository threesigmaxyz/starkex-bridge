// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";
import { OnlyTokenAdmin } from "src/modifiers/OnlyTokenAdmin.sol";
import { ITokenRegisterFacet } from "src/interfaces/facets/ITokenRegisterFacet.sol";

contract TokenRegisterFacet is OnlyTokenAdmin, ITokenRegisterFacet {
    /// @inheritdoc ITokenRegisterFacet
    function setTokenRegister(address token_, bool flag_) external override onlyTokenAdmin {
        LibTokenRegister.setTokenRegister(token_, flag_);
    }

    /// @inheritdoc ITokenRegisterFacet
    function isTokenRegistered(address token_) external view override returns (bool) {
        return LibTokenRegister.isTokenRegistered(token_);
    }
}
