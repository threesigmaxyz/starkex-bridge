//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC165 } from "@openzeppelin/interfaces/IERC165.sol";

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { IDiamondCut } from "src/interfaces/facets/IDiamondCut.sol";
import { IDiamondLoupe } from "src/interfaces/facets/IDiamondLoupe.sol";
import { IERC165Facet } from "src/interfaces/facets/IERC165Facet.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

contract ERC165FacetTest is BaseFixture {
    //==============================================================================//
    //=== Events                                                                 ===//
    //==============================================================================//

    event LogSetSupportedInterface(bytes4 indexed interfaceId, bool indexed flag);

    //==============================================================================//
    //=== initialize Tests                                                      ===//
    //==============================================================================//

    function test_initialize_ok() public {
        assertEq(IERC165Facet(_bridge).supportsInterface(type(IERC165).interfaceId), true);
        assertEq(IERC165Facet(_bridge).supportsInterface(type(IDiamondCut).interfaceId), true);
        assertEq(IERC165Facet(_bridge).supportsInterface(type(IDiamondLoupe).interfaceId), true);
    }

    //==============================================================================//
    //=== setSupportedInterface Tests                                            ===//
    //==============================================================================//

    function test_setSupportedInterface_ok(bytes4 interfaceId1_, bytes4 interfaceId2_) public {
        // Act + Assert
        _setSupportedInterface(interfaceId1_, true);
        _setSupportedInterface(interfaceId2_, true);
        _setSupportedInterface(interfaceId1_, false);
        _setSupportedInterface(interfaceId2_, false);
        _setSupportedInterface(interfaceId1_, true);
        _setSupportedInterface(interfaceId2_, true);
    }

    function test_setSupportedInterface_UnauthorizedError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.UnauthorizedError.selector));

        // Act + Assert
        vm.prank(_intruder());
        IERC165Facet(_bridge).setSupportedInterface(0x12345678, true);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _setSupportedInterface(bytes4 interfaceId_, bool flag_) internal {
        // Arrange
        vm.expectEmit(true, true, false, true, _bridge);
        emit LogSetSupportedInterface(interfaceId_, flag_);

        // Act + Assert
        vm.prank(_owner());
        IERC165Facet(_bridge).setSupportedInterface(interfaceId_, flag_);

        // Assert
        assertEq(IERC165Facet(_bridge).supportsInterface(interfaceId_), flag_);
    }
}
