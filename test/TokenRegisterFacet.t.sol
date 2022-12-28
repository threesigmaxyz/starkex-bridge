//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { ITokenRegisterFacet } from "src/interfaces/facets/ITokenRegisterFacet.sol";
import { console } from "@forge-std/Test.sol";

contract TokenRegisterFacetTest is BaseFixture {
    //==============================================================================//
    //=== Events                                                                 ===//
    //==============================================================================//

    event LogSetTokenRegister(address indexed token, bool indexed flag);

    function test_setTokenRegister_And_isTokenRegistered_Ok(address token1, address token2) public {
        // Arrange
        vm.label(token1, "token1");
        vm.label(token2, "token2");
        vm.startPrank(_tokenAdmin());

        // Act + Assert
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token1), false);
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token2), false);
        // And
        _call_setTokenRegister_and_Validate(token1, true);
        _call_setTokenRegister_and_Validate(token2, true);
        // And
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token1), true);
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token2), true);
        // And
        _call_setTokenRegister_and_Validate(token1, false);
        _call_setTokenRegister_and_Validate(token2, false);
        // And
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token1), false);
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token2), false);

        vm.stopPrank();
    }

    function test_setTokenRegister_NotTokenAdmin() public {
        // Arrange
        address token1 = vm.addr(12345);
        vm.label(token1, "token1");
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.UnauthorizedError.selector));

        // Act + Assert
        ITokenRegisterFacet(_bridge).setTokenRegister(token1, true);
    }
    
    function _call_setTokenRegister_and_Validate(address token, bool flag) internal {
        vm.expectEmit(true, true, false, true, _bridge);
        emit LogSetTokenRegister(token, flag);
        ITokenRegisterFacet(_bridge).setTokenRegister(token, flag);
        assertEq(ITokenRegisterFacet(_bridge).isTokenRegistered(token), flag);
    }
}
