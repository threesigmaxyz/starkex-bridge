//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { IERC165Facet }        from "src/interfaces/IERC165Facet.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

contract DepositFacetTest is BaseFixture {

    function test_changeSupportedInterface_ok() public {
        bytes4 interfaceId = 0x12345678; 

        vm.startPrank(_owner());

        IERC165Facet(bridge).changeSupportedInterface(interfaceId, true);
        assertEq(IERC165Facet(bridge).supportsInterface(interfaceId), true);

        IERC165Facet(bridge).changeSupportedInterface(interfaceId, false);
        assertEq(IERC165Facet(bridge).supportsInterface(interfaceId), false);

        vm.stopPrank();
    }

    function test_changeSupportedInterface_notOwner() public {
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.Unauthorized.selector));
        IERC165Facet(bridge).changeSupportedInterface(0x12345678, true);
    }
}