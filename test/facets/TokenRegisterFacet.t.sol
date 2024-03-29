//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { ITokenRegisterFacet } from "src/interfaces/facets/ITokenRegisterFacet.sol";

contract TokenRegisterFacetTest is BaseFixture {
    //==============================================================================//
    //=== Events                                                                 ===//
    //==============================================================================//

    event LogSetTokenRegister(address indexed token, bool indexed flag);

    //==============================================================================//
    //=== setTokenRegister and isTokenRegisteredTests                            ===//
    //==============================================================================//

    function test_setTokenRegister_and_isTokenRegistered_ok() public {
        // Arrange
        address token1_ = vm.addr(1);
        address token2_ = vm.addr(2);
        vm.label(token1_, "token1");
        vm.label(token2_, "token2");

        // Act + Assert
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token1_), false);
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token2_), false);
        // And
        _setTokenRegister(_bridge, token1_, true);
        _setTokenRegister(_bridge, token2_, true);
        // And
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token1_), true);
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token2_), true);
        // And
        _setTokenRegister(_bridge, token1_, false);
        _setTokenRegister(_bridge, token2_, false);
        // And
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token1_), false);
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token2_), false);
    }

    function test_setTokenRegister_UnauthorizedError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.UnauthorizedError.selector));

        // Act + Assert
        vm.prank(_intruder());
        ITokenRegisterFacet(_bridge).setTokenRegister(vm.addr(1), true);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _setTokenRegister(address bridge_, address token_, bool flag_) internal {
        // Arrange
        vm.expectEmit(true, true, false, true, bridge_);
        emit LogSetTokenRegister(token_, flag_);

        // Act + Assert
        vm.prank(_tokenAdmin());
        ITokenRegisterFacet(_bridge).setTokenRegister(token_, flag_);
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token_), flag_);
    }
}
