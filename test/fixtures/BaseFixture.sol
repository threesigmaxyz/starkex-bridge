//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";

import { BridgeDiamond }    from "src/BridgeDiamond.sol";

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

import { AccessControlFacet } from "src/facets/AccessControlFacet.sol";
import { DepositFacet }       from "src/facets/DepositFacet.sol";
import { DiamondCutFacet }    from "src/facets/DiamondCutFacet.sol";
import { TokenRegisterFacet } from "src/facets/TokenRegisterFacet.sol";
import { WithdrawalFacet }    from "src/facets/WithdrawalFacet.sol";
import { StateFacet }    from "src/facets/StateFacet.sol";

import { IDiamondCut }         from "src/interfaces/IDiamondCut.sol";
import { IAccessControlFacet } from "src/interfaces/IAccessControlFacet.sol";
import { IDepositFacet }       from "src/interfaces/IDepositFacet.sol";
import { ITokenRegisterFacet } from "src/interfaces/ITokenRegisterFacet.sol";
import { IWithdrawalFacet }    from "src/interfaces/IWithdrawalFacet.sol";
import { IStateFacet }    from "src/interfaces/IStateFacet.sol";
// TODO import { IDiamondCutFacet } from "src/interfaces/IDiamondCutFacet.sol";

contract BaseFixture is Test {

    address bridge;

    AccessControlFacet accessControlFacet = new AccessControlFacet();
    DepositFacet depositFacet = new DepositFacet();
    DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
    TokenRegisterFacet tokenRegisterFacet = new TokenRegisterFacet();
    WithdrawalFacet withdrawalFacet = new WithdrawalFacet();
    StateFacet stateFacet = new StateFacet();

    function setUp() virtual public {
        // Deploy diamond
        BridgeDiamond.ConstructorArgs memory args_ = BridgeDiamond.ConstructorArgs({
            owner: _owner(),
            starkExOperator: _operator(),
            interoperabilityContract: _mockInteropContract(),
            tokenAdmin: _tokenAdmin(),
            diamondCutFacet: address(diamondCutFacet)
        });
        bridge = address(new BridgeDiamond(args_));

        // Cut diamond
        IDiamondCut.FacetCut[] memory cut_ = new IDiamondCut.FacetCut[](5);

        // Access Control facet
        bytes4[] memory accessControlFacetSelectors_ = new bytes4[](3);
        accessControlFacetSelectors_[0] = IAccessControlFacet.acceptRole.selector;
        accessControlFacetSelectors_[1] = IAccessControlFacet.setPendingRole.selector;
        accessControlFacetSelectors_[2] = IAccessControlFacet.getRole.selector;
        cut_[0] = IDiamondCut.FacetCut({
            facetAddress: address(accessControlFacet), 
            action: IDiamondCut.FacetCutAction.Add, 
            functionSelectors: accessControlFacetSelectors_
        });

        // Deposit facet
        bytes4[] memory depositFacetSelectors_ = new bytes4[](5);
        depositFacetSelectors_[0] = IDepositFacet.lockDeposit.selector;
        depositFacetSelectors_[1] = IDepositFacet.claimDeposit.selector;
        depositFacetSelectors_[2] = IDepositFacet.reclaimDeposit.selector;
        depositFacetSelectors_[3] = IDepositFacet.getDeposit.selector;
        depositFacetSelectors_[4] = IDepositFacet.getPendingDeposits.selector;
        cut_[1] = IDiamondCut.FacetCut({
            facetAddress: address(depositFacet), 
            action: IDiamondCut.FacetCutAction.Add, 
            functionSelectors: depositFacetSelectors_
        });

        // Token Register facet
        bytes4[] memory tokenRegisterFacetSelectors_ = new bytes4[](2);
        tokenRegisterFacetSelectors_[0] = ITokenRegisterFacet.setTokenRegister.selector;
        tokenRegisterFacetSelectors_[1] = ITokenRegisterFacet.isTokenRegistered.selector;
        cut_[2] = IDiamondCut.FacetCut({
            facetAddress: address(tokenRegisterFacet), 
            action: IDiamondCut.FacetCutAction.Add, 
            functionSelectors: tokenRegisterFacetSelectors_
        });

        // Withdrawal Register facet
        bytes4[] memory withdrawalFacetSelectors_ = new bytes4[](5);
        withdrawalFacetSelectors_[0] = IWithdrawalFacet.lockWithdrawal.selector;
        withdrawalFacetSelectors_[1] = IWithdrawalFacet.claimWithdrawal.selector;
        withdrawalFacetSelectors_[2] = IWithdrawalFacet.reclaimWithdrawal.selector;
        withdrawalFacetSelectors_[3] = IWithdrawalFacet.getWithdrawal.selector;
        withdrawalFacetSelectors_[4] = IWithdrawalFacet.getPendingWithdrawals.selector;
        cut_[3] = IDiamondCut.FacetCut({
            facetAddress: address(withdrawalFacet), 
            action: IDiamondCut.FacetCutAction.Add, 
            functionSelectors: withdrawalFacetSelectors_
        });

        // State facet
        bytes4[] memory stateFacetSelectors_ = new bytes4[](2);
        stateFacetSelectors_[0] = IStateFacet.getOrderRoot.selector;
        stateFacetSelectors_[1] = IStateFacet.setOrderRoot.selector;
        cut_[4] = IDiamondCut.FacetCut({
            facetAddress: address(stateFacet), 
            action: IDiamondCut.FacetCutAction.Add, 
            functionSelectors: stateFacetSelectors_
        });

        // Cut diamond finalize
        vm.prank(_owner());
        IDiamondCut(address(bridge)).diamondCut(cut_, address(0), "");

        /// Accept roles other than the owner.
        vm.prank(_operator());
        IAccessControlFacet(bridge).acceptRole(LibAccessControl.STARKEX_OPERATOR_ROLE);
        vm.prank(_mockInteropContract());
        IAccessControlFacet(bridge).acceptRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);
        vm.prank(_tokenAdmin());
        IAccessControlFacet(bridge).acceptRole(LibAccessControl.TOKEN_ADMIN_ROLE);
    }

    function _owner() internal returns (address) {
        return vm.addr(1337);
    }

    function _operator() internal returns (address) {
        return vm.addr(420);
    }

    function _mockInteropContract() internal returns (address) {
        return vm.addr(1338);
    }

    function _tokenAdmin() internal returns (address) {
        return vm.addr(888);
    }

    function _tokenDeployer() internal returns (address) {
        return vm.addr(666);
    }
}