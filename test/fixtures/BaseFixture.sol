//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";

import { Constants } from "src/constants/Constants.sol";

import { BridgeDiamond } from "src/BridgeDiamond.sol";

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

import { AccessControlFacet } from "src/facets/AccessControlFacet.sol";
import { DepositFacet } from "src/facets/DepositFacet.sol";
import { DiamondCutFacet } from "src/facets/DiamondCutFacet.sol";
import { TokenRegisterFacet } from "src/facets/TokenRegisterFacet.sol";
import { WithdrawalFacet } from "src/facets/WithdrawalFacet.sol";
import { StateFacet } from "src/facets/StateFacet.sol";
import { ERC165Facet } from "src/facets/ERC165Facet.sol";

import { IDiamondCut } from "src/interfaces/facets/IDiamondCut.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IDepositFacet } from "src/interfaces/facets/IDepositFacet.sol";
import { ITokenRegisterFacet } from "src/interfaces/facets/ITokenRegisterFacet.sol";
import { IWithdrawalFacet } from "src/interfaces/facets/IWithdrawalFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { IERC165Facet } from "src/interfaces/facets/IERC165Facet.sol";
import { IDiamondLoupe } from "src/interfaces/facets/IDiamondLoupe.sol";
import { IERC165 } from "@openzeppelin/interfaces/IERC165.sol";

contract BaseFixture is Test {
    uint256 internal constant USER_TOKENS = 10;

    address _bridge;

    AccessControlFacet accessControlFacet = new AccessControlFacet();
    DepositFacet depositFacet = new DepositFacet();
    DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
    TokenRegisterFacet tokenRegisterFacet = new TokenRegisterFacet();
    WithdrawalFacet withdrawalFacet = new WithdrawalFacet();
    StateFacet stateFacet = new StateFacet();
    ERC165Facet erc165Facet = new ERC165Facet();

    function setUp() public virtual {
        vm.label(_owner(), "owner");
        vm.label(_operator(), "operator");
        vm.label(_mockInteropContract(), "mockInteropContract");
        vm.label(_tokenAdmin(), "tokenAdmin");
        vm.label(_tokenDeployer(), "tokenDeployer");
        vm.label(_user(), "user");
        vm.label(_recipient(), "recipient");

        // Deploy diamond
        _bridge = address(new BridgeDiamond(_owner(), address(diamondCutFacet)));

        /// @dev Cut the deposit facet alone to initialize it.
        IDiamondCut.FacetCut[] memory depositCut_ = new IDiamondCut.FacetCut[](1);
        // Deposit facet.
        bytes4[] memory depositFacetSelectors_ = new bytes4[](7);
        depositFacetSelectors_[0] = IDepositFacet.setDepositExpirationTimeout.selector;
        depositFacetSelectors_[1] = IDepositFacet.lockDeposit.selector;
        depositFacetSelectors_[2] = IDepositFacet.claimDeposit.selector;
        depositFacetSelectors_[3] = IDepositFacet.reclaimDeposit.selector;
        depositFacetSelectors_[4] = IDepositFacet.getDeposit.selector;
        depositFacetSelectors_[5] = IDepositFacet.getPendingDeposits.selector;
        depositFacetSelectors_[6] = IDepositFacet.getDepositExpirationTimeout.selector;
        depositCut_[0] = IDiamondCut.FacetCut({
            facetAddress: address(depositFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: depositFacetSelectors_
        });
        bytes memory depositInitializer = abi.encodeWithSelector(
            depositFacet.setDepositExpirationTimeout.selector,
            Constants.DEPOSIT_ONCHAIN_EXPIRATION_TIMEOUT
        );
        vm.startPrank(_owner());
        IDiamondCut(address(_bridge)).diamondCut(depositCut_, address(depositFacet), depositInitializer);

        /// @dev Cut the withdrawal facet alone to initialize it.
        IDiamondCut.FacetCut[] memory withdrawalCut_ = new IDiamondCut.FacetCut[](1);
        /// Withdrawal facet.
        bytes4[] memory withdrawalFacetSelectors_ = new bytes4[](7);
        withdrawalFacetSelectors_[0] = IWithdrawalFacet.setWithdrawalExpirationTimeout.selector;
        withdrawalFacetSelectors_[1] = IWithdrawalFacet.lockWithdrawal.selector;
        withdrawalFacetSelectors_[2] = IWithdrawalFacet.claimWithdrawal.selector;
        withdrawalFacetSelectors_[3] = IWithdrawalFacet.reclaimWithdrawal.selector;
        withdrawalFacetSelectors_[4] = IWithdrawalFacet.getWithdrawal.selector;
        withdrawalFacetSelectors_[5] = IWithdrawalFacet.getPendingWithdrawals.selector;
        withdrawalFacetSelectors_[6] = IWithdrawalFacet.getWithdrawalExpirationTimeout.selector;
        withdrawalCut_[0] = IDiamondCut.FacetCut({
            facetAddress: address(withdrawalFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: withdrawalFacetSelectors_
        });
        bytes memory withdrawalInitializer = abi.encodeWithSelector(
            withdrawalFacet.setWithdrawalExpirationTimeout.selector,
            Constants.WITHDRAWAL_ONCHAIN_EXPIRATION_TIMEOUT
        );
        IDiamondCut(address(_bridge)).diamondCut(withdrawalCut_, address(withdrawalFacet), withdrawalInitializer);

        /// @dev cut access control, token register, state and ERC165 facets.
        IDiamondCut.FacetCut[] memory cut_ = new IDiamondCut.FacetCut[](4);

        // Access Control facet.
        bytes4[] memory accessControlFacetSelectors_ = new bytes4[](3);
        accessControlFacetSelectors_[0] = IAccessControlFacet.acceptRole.selector;
        accessControlFacetSelectors_[1] = IAccessControlFacet.setPendingRole.selector;
        accessControlFacetSelectors_[2] = IAccessControlFacet.getRole.selector;
        cut_[0] = IDiamondCut.FacetCut({
            facetAddress: address(accessControlFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: accessControlFacetSelectors_
        });

        // Token Register facet
        bytes4[] memory tokenRegisterFacetSelectors_ = new bytes4[](2);
        tokenRegisterFacetSelectors_[0] = ITokenRegisterFacet.setTokenRegister.selector;
        tokenRegisterFacetSelectors_[1] = ITokenRegisterFacet.isTokenRegistered.selector;
        cut_[1] = IDiamondCut.FacetCut({
            facetAddress: address(tokenRegisterFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: tokenRegisterFacetSelectors_
        });

        // State facet
        bytes4[] memory stateFacetSelectors_ = new bytes4[](2);
        stateFacetSelectors_[0] = IStateFacet.getOrderRoot.selector;
        stateFacetSelectors_[1] = IStateFacet.setOrderRoot.selector;
        cut_[2] = IDiamondCut.FacetCut({
            facetAddress: address(stateFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: stateFacetSelectors_
        });

        // State facet
        bytes4[] memory erc165FacetSelectors_ = new bytes4[](2);
        erc165FacetSelectors_[0] = IERC165Facet.supportsInterface.selector;
        erc165FacetSelectors_[1] = IERC165Facet.setSupportedInterface.selector;
        cut_[3] = IDiamondCut.FacetCut({
            facetAddress: address(erc165Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc165FacetSelectors_
        });

        /// Cut diamond finalize.
        IDiamondCut(address(_bridge)).diamondCut(cut_, address(0), "");

        /// Set pending roles.
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.STARKEX_OPERATOR_ROLE, _operator());
        IAccessControlFacet(_bridge).setPendingRole(
            LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE, _mockInteropContract()
        );
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.TOKEN_ADMIN_ROLE, _tokenAdmin());

        vm.stopPrank();

        /// Accept pending roles.
        vm.prank(_operator());
        IAccessControlFacet(_bridge).acceptRole(LibAccessControl.STARKEX_OPERATOR_ROLE);
        vm.prank(_mockInteropContract());
        IAccessControlFacet(_bridge).acceptRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);
        vm.prank(_tokenAdmin());
        IAccessControlFacet(_bridge).acceptRole(LibAccessControl.TOKEN_ADMIN_ROLE);

        // Add ERC165 interfaces
        vm.startPrank(_owner());
        IERC165Facet(_bridge).setSupportedInterface(type(IERC165).interfaceId, true);
        IERC165Facet(_bridge).setSupportedInterface(type(IDiamondCut).interfaceId, true);
        IERC165Facet(_bridge).setSupportedInterface(type(IDiamondLoupe).interfaceId, true);
        vm.stopPrank();
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

    function _user() internal returns (address) {
        return vm.addr(789);
    }

    function _recipient() internal returns(address) {
        return vm.addr(777);
    }
}
