// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BaseFixture } from "test/fixtures/BaseFixture.sol";

import { Constants } from "src/constants/Constants.sol";

import { IDiamondCut } from "src/interfaces/facets/IDiamondCut.sol";
import { IDepositFacet } from "src/interfaces/facets/IDepositFacet.sol";
import { IWithdrawalFacet } from "src/interfaces/facets/IWithdrawalFacet.sol";
import { IDiamondLoupe } from "src/interfaces/facets/IDiamondLoupe.sol";

import { AccessControlFacet } from "src/facets/AccessControlFacet.sol";
import { DepositFacet } from "src/facets/DepositFacet.sol";
import { DiamondCutFacet } from "src/facets/DiamondCutFacet.sol";
import { TokenRegisterFacet } from "src/facets/TokenRegisterFacet.sol";
import { WithdrawalFacet } from "src/facets/WithdrawalFacet.sol";
import { StateFacet } from "src/facets/StateFacet.sol";
import { ERC165Facet } from "src/facets/ERC165Facet.sol";
import { DiamondLoupeFacet } from "src/facets/DiamondLoupeFacet.sol";

import { LibDeployBridge } from "common/LibDeployBridge.sol";

contract MigrationTest is BaseFixture {
    function testMigration() public {
        LibDeployBridge.Facets memory facets_ = LibDeployBridge.createFacets();

        vm.startPrank(_owner());
        _replaceBridgeFacets(_bridge, facets_);
        vm.stopPrank();

        assertEq(IDepositFacet(_bridge).getDepositExpirationTimeout(), Constants.DEPOSIT_ONCHAIN_EXPIRATION_TIMEOUT);
        assertEq(
            IWithdrawalFacet(_bridge).getWithdrawalExpirationTimeout(), Constants.WITHDRAWAL_ONCHAIN_EXPIRATION_TIMEOUT
        );

        assertEq(IDiamondLoupe(_bridge).facets().length, 8);
        // First facet is diamondCut, which is set by BridgeDiamond.sol.
        assertEq(IDiamondLoupe(_bridge).facets()[1].facetAddress, facets_.deposit);
        assertEq(IDiamondLoupe(_bridge).facets()[2].facetAddress, facets_.withdrawal);
        assertEq(IDiamondLoupe(_bridge).facets()[3].facetAddress, facets_.accessControl);
        assertEq(IDiamondLoupe(_bridge).facets()[4].facetAddress, facets_.tokenRegister);
        assertEq(IDiamondLoupe(_bridge).facets()[5].facetAddress, facets_.state);
        assertEq(IDiamondLoupe(_bridge).facets()[6].facetAddress, facets_.erc165);
        assertEq(IDiamondLoupe(_bridge).facets()[7].facetAddress, facets_.diamondLoupe);

        _assertFacetSelectors(facets_.deposit, LibDeployBridge.getDepositFacetFunctionSelectors());
        _assertFacetSelectors(facets_.withdrawal, LibDeployBridge.getWithdrawalFacetFunctionSelectors());
        _assertFacetSelectors(facets_.accessControl, LibDeployBridge.getAccessControlFacetFunctionSelectors());
        _assertFacetSelectors(facets_.tokenRegister, LibDeployBridge.getTokenRegisterFacetFunctionSelectors());
        _assertFacetSelectors(facets_.state, LibDeployBridge.getStateFacetFunctionSelectors());
        _assertFacetSelectors(facets_.erc165, LibDeployBridge.getErc165FacetFunctionSelectors());
        _assertFacetSelectors(facets_.diamondLoupe, LibDeployBridge.getDiamondLoupeFacetFunctionSelectors());
    }

    function _assertFacetSelectors(address facet_, bytes4[] memory selectors_) internal {
        bytes4[] memory facetSelectors_ = IDiamondLoupe(_bridge).facetFunctionSelectors(facet_);
        assertEq(facetSelectors_.length, selectors_.length);
        for (uint256 i_ = 0; i_ < selectors_.length; i_++) {
            assertEq(facetSelectors_[i_], selectors_[i_]);
        }
    }

    function _replaceBridgeFacets(address bridge_, LibDeployBridge.Facets memory facets_) internal {
        LibDeployBridge.changeBridgeFacets(bridge_, facets_, IDiamondCut.FacetCutAction.Replace);
    }
}
