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

contract MigrationTest is BaseFixture {
    function testMigration() public {
        Facets memory facets_;

        facets_.diamondCut = address(new DiamondCutFacet());
        facets_.deposit = address(new DepositFacet());
        facets_.withdrawal = address(new WithdrawalFacet());
        facets_.accessControl = address(new AccessControlFacet());
        facets_.tokenRegister = address(new TokenRegisterFacet());
        facets_.state = address(new StateFacet());
        facets_.erc165 = address(new ERC165Facet());
        facets_.diamondLoupe = address(new DiamondLoupeFacet());

        vm.startPrank(_owner());
        _replaceBridgeFacets(_bridge, facets_);
        vm.stopPrank();

        assertEq(IDepositFacet(_bridge).getDepositExpirationTimeout(), Constants.DEPOSIT_ONCHAIN_EXPIRATION_TIMEOUT);
        assertEq(
            IWithdrawalFacet(_bridge).getWithdrawalExpirationTimeout(), Constants.WITHDRAWAL_ONCHAIN_EXPIRATION_TIMEOUT
        );

        assertEq(IDiamondLoupe(_bridge).facets().length, 8);
        assertEq(IDiamondLoupe(_bridge).facets()[1].facetAddress, facets_.deposit);
        assertEq(IDiamondLoupe(_bridge).facets()[2].facetAddress, facets_.withdrawal);
        assertEq(IDiamondLoupe(_bridge).facets()[3].facetAddress, facets_.accessControl);
        assertEq(IDiamondLoupe(_bridge).facets()[4].facetAddress, facets_.tokenRegister);
        assertEq(IDiamondLoupe(_bridge).facets()[5].facetAddress, facets_.state);
        assertEq(IDiamondLoupe(_bridge).facets()[6].facetAddress, facets_.erc165);
        assertEq(IDiamondLoupe(_bridge).facets()[7].facetAddress, facets_.diamondLoupe);

        _assertFacetSelectors(facets_.deposit, _getDepositFacetFunctionSelectors());
        _assertFacetSelectors(facets_.withdrawal, _getWithdrawalFacetFunctionSelectors());
        _assertFacetSelectors(facets_.accessControl, _getAccessControlFacetFunctionSelectors());
        _assertFacetSelectors(facets_.tokenRegister, _getTokenRegisterFacetFunctionSelectors());
        _assertFacetSelectors(facets_.state, _getStateFacetFunctionSelectors());
        _assertFacetSelectors(facets_.erc165, _getErc165FacetFunctionSelectors());
        _assertFacetSelectors(facets_.diamondLoupe, _getDiamondLoupeFacetFunctionSelectors());
    }

    function _assertFacetSelectors(address facet_, bytes4[] memory selectors_) internal {
        bytes4[] memory facetSelectors_ = IDiamondLoupe(_bridge).facetFunctionSelectors(facet_);
        assertEq(facetSelectors_.length, selectors_.length);
        for (uint256 i = 0; i < selectors_.length; i++) {
            assertEq(facetSelectors_[i], selectors_[i]);
        }
    }

    function _replaceBridgeFacets(address bridge_, Facets memory facets_) internal {
        _changeBridgeFacets(bridge_, facets_, IDiamondCut.FacetCutAction.Replace);
    }
}
