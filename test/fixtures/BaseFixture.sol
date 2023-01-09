//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";
import { IERC165 } from "@openzeppelin/interfaces/IERC165.sol";

import { Constants } from "src/constants/Constants.sol";

import { MockERC20 } from "test/mocks/MockERC20.sol";

import { BridgeDiamond } from "src/BridgeDiamond.sol";

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

import { AccessControlFacet } from "src/facets/AccessControlFacet.sol";
import { DepositFacet } from "src/facets/DepositFacet.sol";
import { DiamondCutFacet } from "src/facets/DiamondCutFacet.sol";
import { TokenRegisterFacet } from "src/facets/TokenRegisterFacet.sol";
import { WithdrawalFacet } from "src/facets/WithdrawalFacet.sol";
import { StateFacet } from "src/facets/StateFacet.sol";
import { ERC165Facet } from "src/facets/ERC165Facet.sol";
import { DiamondLoupeFacet } from "src/facets/DiamondLoupeFacet.sol";

import { IDiamondCut } from "src/interfaces/facets/IDiamondCut.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IDepositFacet } from "src/interfaces/facets/IDepositFacet.sol";
import { ITokenRegisterFacet } from "src/interfaces/facets/ITokenRegisterFacet.sol";
import { IWithdrawalFacet } from "src/interfaces/facets/IWithdrawalFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { IERC165Facet } from "src/interfaces/facets/IERC165Facet.sol";
import { IDiamondLoupe } from "src/interfaces/facets/IDiamondLoupe.sol";

contract BaseFixture is Test {
    struct Facets {
        address accessControl;
        address deposit;
        address diamondCut;
        address tokenRegister;
        address withdrawal;
        address state;
        address erc165;
        address diamondLoupe;
    }

    uint256 internal constant USER_TOKENS = type(uint256).max;

    address _bridge;
    MockERC20 _token;

    function setUp() public virtual {
        _setLabels();

        Facets memory facets_;

        facets_.accessControl = address(new AccessControlFacet());
        facets_.deposit = address(new DepositFacet());
        facets_.diamondCut = address(new DiamondCutFacet());
        facets_.tokenRegister = address(new TokenRegisterFacet());
        facets_.withdrawal = address(new WithdrawalFacet());
        facets_.state = address(new StateFacet());
        facets_.erc165 = address(new ERC165Facet());
        facets_.diamondLoupe = address(new DiamondLoupeFacet());

        vm.startPrank(_owner());
        _bridge = _deployBridge(_owner(), facets_);
        _setPendingRoles(_bridge, _mockInteropContract());
        vm.stopPrank();

        _acceptPendingRoles(_bridge);

        // Has to be separate from the above because the interop role might be a contract.
        vm.prank(_mockInteropContract());
        IAccessControlFacet(_bridge).acceptRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);

        // Deploy _token
        vm.prank(_tokenDeployer());
        _token = (new MockERC20){salt: "USDC"}("USD Coin", "USDC", 6); // 0xa33e385d3ab4a55cc949115bb5cb57fb16143d4b

        _token.mint(_user(), USER_TOKENS);

        // Register _token in _bridge
        vm.prank(_tokenAdmin());
        ITokenRegisterFacet(_bridge).setTokenRegister(address(_token), true);
    }

    function _deployBridge(address owner_, Facets memory facets_) internal returns (address) {
        // Deploy diamond
        address bridge_ = address(new BridgeDiamond(owner_, facets_.diamondCut));
        _addFacetsToBridge(bridge_, facets_);
        return bridge_;
    }

    function _addFacetsToBridge(address bridge_, Facets memory facets_) internal {
        _changeBridgeFacets(bridge_, facets_, IDiamondCut.FacetCutAction.Add);
    }

    function _changeBridgeFacets(address bridge_, Facets memory facets_, IDiamondCut.FacetCutAction action_) internal {
        // Cut the deposit facet alone to initialize it.
        IDiamondCut.FacetCut[] memory depositCut_ = new IDiamondCut.FacetCut[](1);
        // Deposit facet.
        depositCut_[0] = IDiamondCut.FacetCut({
            facetAddress: facets_.deposit,
            action: action_,
            functionSelectors: _getDepositFacetFunctionSelectors()
        });
        bytes memory depositInitializer = abi.encodeWithSelector(
            IDepositFacet.setDepositExpirationTimeout.selector, Constants.DEPOSIT_ONCHAIN_EXPIRATION_TIMEOUT
        );
        IDiamondCut(bridge_).diamondCut(depositCut_, facets_.deposit, depositInitializer);

        /// @dev Cut the withdrawal facet alone to initialize it.
        IDiamondCut.FacetCut[] memory withdrawalCut_ = new IDiamondCut.FacetCut[](1);
        /// Withdrawal facet.
        withdrawalCut_[0] = IDiamondCut.FacetCut({
            facetAddress: facets_.withdrawal,
            action: action_,
            functionSelectors: _getWithdrawalFacetFunctionSelectors()
        });
        bytes memory withdrawalInitializer = abi.encodeWithSelector(
            IWithdrawalFacet.setWithdrawalExpirationTimeout.selector, Constants.WITHDRAWAL_ONCHAIN_EXPIRATION_TIMEOUT
        );
        IDiamondCut(bridge_).diamondCut(withdrawalCut_, facets_.withdrawal, withdrawalInitializer);

        /// @dev cut access control, token register, state and ERC165 facets.
        IDiamondCut.FacetCut[] memory cut_ = new IDiamondCut.FacetCut[](5);

        // Access Control facet.
        cut_[0] = IDiamondCut.FacetCut({
            facetAddress: facets_.accessControl,
            action: action_,
            functionSelectors: _getAccessControlFacetFunctionSelectors()
        });

        // Token Register facet
        cut_[1] = IDiamondCut.FacetCut({
            facetAddress: facets_.tokenRegister,
            action: action_,
            functionSelectors: _getTokenRegisterFacetFunctionSelectors()
        });

        // State facet
        cut_[2] = IDiamondCut.FacetCut({
            facetAddress: facets_.state,
            action: action_,
            functionSelectors: _getStateFacetFunctionSelectors()
        });

        // State facet
        cut_[3] = IDiamondCut.FacetCut({
            facetAddress: facets_.erc165,
            action: action_,
            functionSelectors: _getErc165FacetFunctionSelectors()
        });

        // Diamond Loup facet
        cut_[4] = IDiamondCut.FacetCut({
            facetAddress: facets_.diamondLoupe,
            action: action_,
            functionSelectors: _getDiamondLoupeFacetFunctionSelectors()
        });

        /// Cut diamond finalize.
        IDiamondCut(bridge_).diamondCut(cut_, address(0), "");

        // Add ERC165 interfaces
        IERC165Facet(bridge_).setSupportedInterface(type(IERC165).interfaceId, true);
        IERC165Facet(bridge_).setSupportedInterface(type(IDiamondCut).interfaceId, true);
        IERC165Facet(bridge_).setSupportedInterface(type(IDiamondLoupe).interfaceId, true);
    }

    function _getDepositFacetFunctionSelectors() internal pure returns(bytes4[] memory) {
        bytes4[] memory depositFacetSelectors_ = new bytes4[](7);
        depositFacetSelectors_[0] = IDepositFacet.setDepositExpirationTimeout.selector;
        depositFacetSelectors_[1] = IDepositFacet.lockDeposit.selector;
        depositFacetSelectors_[2] = IDepositFacet.claimDeposit.selector;
        depositFacetSelectors_[3] = IDepositFacet.reclaimDeposit.selector;
        depositFacetSelectors_[4] = IDepositFacet.getDeposit.selector;
        depositFacetSelectors_[5] = IDepositFacet.getPendingDeposits.selector;
        depositFacetSelectors_[6] = IDepositFacet.getDepositExpirationTimeout.selector;
        return depositFacetSelectors_;
    }

    function _getWithdrawalFacetFunctionSelectors() internal pure returns(bytes4[] memory) {
        bytes4[] memory withdrawalFacetSelectors_ = new bytes4[](7);
        withdrawalFacetSelectors_[0] = IWithdrawalFacet.setWithdrawalExpirationTimeout.selector;
        withdrawalFacetSelectors_[1] = IWithdrawalFacet.lockWithdrawal.selector;
        withdrawalFacetSelectors_[2] = IWithdrawalFacet.claimWithdrawal.selector;
        withdrawalFacetSelectors_[3] = IWithdrawalFacet.reclaimWithdrawal.selector;
        withdrawalFacetSelectors_[4] = IWithdrawalFacet.getWithdrawal.selector;
        withdrawalFacetSelectors_[5] = IWithdrawalFacet.getPendingWithdrawals.selector;
        withdrawalFacetSelectors_[6] = IWithdrawalFacet.getWithdrawalExpirationTimeout.selector;
        return withdrawalFacetSelectors_;
    }

    function _getAccessControlFacetFunctionSelectors() internal pure returns(bytes4[] memory) {
        bytes4[] memory accessControlFacetSelectors_ = new bytes4[](3);
        accessControlFacetSelectors_[0] = IAccessControlFacet.acceptRole.selector;
        accessControlFacetSelectors_[1] = IAccessControlFacet.setPendingRole.selector;
        accessControlFacetSelectors_[2] = IAccessControlFacet.getRole.selector;
        return accessControlFacetSelectors_;
    }

    function _getTokenRegisterFacetFunctionSelectors() internal pure returns(bytes4[] memory) {
        bytes4[] memory tokenRegisterFacetSelectors_ = new bytes4[](2);
        tokenRegisterFacetSelectors_[0] = ITokenRegisterFacet.setTokenRegister.selector;
        tokenRegisterFacetSelectors_[1] = ITokenRegisterFacet.isTokenRegistered.selector;
        return tokenRegisterFacetSelectors_;
    }

    function _getStateFacetFunctionSelectors() internal pure returns(bytes4[] memory) {
        bytes4[] memory stateFacetSelectors_ = new bytes4[](2);
        stateFacetSelectors_[0] = IStateFacet.getOrderRoot.selector;
        stateFacetSelectors_[1] = IStateFacet.setOrderRoot.selector;
        return stateFacetSelectors_;
    }

    function _getErc165FacetFunctionSelectors() internal pure returns(bytes4[] memory) {
        bytes4[] memory erc165FacetSelectors_ = new bytes4[](2);
        erc165FacetSelectors_[0] = IERC165Facet.supportsInterface.selector;
        erc165FacetSelectors_[1] = IERC165Facet.setSupportedInterface.selector;
        return erc165FacetSelectors_;
    }

    function _getDiamondLoupeFacetFunctionSelectors() internal pure returns(bytes4[] memory) {
        bytes4[] memory diamondLoupeFacetSelectors_ = new bytes4[](4);
        diamondLoupeFacetSelectors_[0] = IDiamondLoupe.facets.selector;
        diamondLoupeFacetSelectors_[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        diamondLoupeFacetSelectors_[2] = IDiamondLoupe.facetAddresses.selector;
        diamondLoupeFacetSelectors_[3] = IDiamondLoupe.facetAddress.selector;
        return diamondLoupeFacetSelectors_;
    }

    function _setPendingRoles(address bridge_, address interoperabilityContract_) internal {
        IAccessControlFacet(bridge_).setPendingRole(LibAccessControl.STARKEX_OPERATOR_ROLE, _operator());
        IAccessControlFacet(bridge_).setPendingRole(
            LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE, interoperabilityContract_
        );
        IAccessControlFacet(bridge_).setPendingRole(LibAccessControl.TOKEN_ADMIN_ROLE, _tokenAdmin());
    }

    function _acceptPendingRoles(address bridge_) internal {
        vm.prank(_operator());
        IAccessControlFacet(bridge_).acceptRole(LibAccessControl.STARKEX_OPERATOR_ROLE);
        vm.prank(_tokenAdmin());
        IAccessControlFacet(bridge_).acceptRole(LibAccessControl.TOKEN_ADMIN_ROLE);
    }

    function _setLabels() internal {
        vm.label(_owner(), "owner");
        vm.label(_operator(), "operator");
        vm.label(_mockInteropContract(), "mockInteropContract");
        vm.label(_tokenAdmin(), "tokenAdmin");
        vm.label(_tokenDeployer(), "tokenDeployer");
        vm.label(_user(), "user");
        vm.label(_recipient(), "recipient");
        vm.label(_intruder(), "intruder");
    }

    function _owner() internal pure returns (address) {
        return vm.addr(1337);
    }

    function _operator() internal pure returns (address) {
        return vm.addr(420);
    }

    function _mockInteropContract() internal pure returns (address) {
        return vm.addr(1338);
    }

    function _tokenAdmin() internal pure returns (address) {
        return vm.addr(888);
    }

    function _tokenDeployer() internal pure returns (address) {
        return vm.addr(666);
    }

    function _user() internal pure returns (address) {
        return vm.addr(789);
    }

    function _recipient() internal pure returns (address) {
        return vm.addr(777);
    }

    function _intruder() internal pure returns (address) {
        return vm.addr(999);
    }
}
