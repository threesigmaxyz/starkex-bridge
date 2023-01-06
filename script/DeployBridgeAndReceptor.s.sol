//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { BridgeDiamond } from "src/BridgeDiamond.sol";

import { Constants } from "src/constants/Constants.sol";

import { DiamondLoupeFacet } from "src/facets/DiamondLoupeFacet.sol";
import { AccessControlFacet } from "src/facets/AccessControlFacet.sol";
import { DepositFacet } from "src/facets/DepositFacet.sol";
import { DiamondCutFacet } from "src/facets/DiamondCutFacet.sol";
import { TokenRegisterFacet } from "src/facets/TokenRegisterFacet.sol";
import { WithdrawalFacet } from "src/facets/WithdrawalFacet.sol";
import { StateFacet } from "src/facets/StateFacet.sol";
import { ERC165Facet } from "src/facets/ERC165Facet.sol";

import { IDiamondCut } from "src/interfaces/facets/IDiamondCut.sol";
import { IDiamondLoupe } from "src/interfaces/facets/IDiamondLoupe.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IDepositFacet } from "src/interfaces/facets/IDepositFacet.sol";
import { ITokenRegisterFacet } from "src/interfaces/facets/ITokenRegisterFacet.sol";
import { IWithdrawalFacet } from "src/interfaces/facets/IWithdrawalFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { IERC165Facet } from "src/interfaces/facets/IERC165Facet.sol";
import { IERC165 } from "@openzeppelin/interfaces/IERC165.sol";

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

import { LzReceptor } from "src/interoperability/LzReceptor.sol";

import { DataIO } from "script/data/DataIO.sol";

contract DeployBridgeAndReceptorModuleScript is Script, DataIO {
    struct Facets {
        address accessControl;
        address deposit;
        address diamondCut;
        address tokenRegister;
        address withdrawal;
        address state;
        address erc165;
    }

    address public _owner;
    address public _operator;
    address public _tokenAdmin;
    address public _bridge;
    address public _lzEndpoint;

    LzReceptor public _receptor;

    function setUp() public {
        _owner = vm.rememberKey(vm.envUint("OWNER_PRIVATE_KEY"));
        _operator = vm.envAddress("STARKEX_OPERATOR");
        _tokenAdmin = vm.envAddress("TOKEN_ADMIN");
        _lzEndpoint = vm.envAddress("LAYER_ZERO_ENDPOINT");
    }

    function run() external {
        // Record calls and contract creations made by our script contract.
        vm.startBroadcast(_owner);

        // Deploy facets.
        Facets memory facets_;

        facets_.accessControl = address(new AccessControlFacet());
        facets_.deposit = address(new DepositFacet());
        facets_.diamondCut = address(new DiamondCutFacet());
        facets_.tokenRegister = address(new TokenRegisterFacet());
        facets_.withdrawal = address(new WithdrawalFacet());
        facets_.state = address(new StateFacet());
        facets_.erc165 = address(new ERC165Facet());

        // Deploy bridge.
        _bridge = _deployBridge(_owner, facets_);
        _writeData("bridge", vm.toString(abi.encodePacked((_bridge))));

        // Deploy recepetor
        _receptor = new LzReceptor(_lzEndpoint, _bridge);
        _writeData("receptor", vm.toString(address(_receptor)));

        // Set pending roles.
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.STARKEX_OPERATOR_ROLE, _operator);
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.TOKEN_ADMIN_ROLE, _tokenAdmin);
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE, address(_receptor));

        // Accept interoperability role.
        _receptor.acceptBridgeRole();

        // Stop recording calls.
        vm.stopBroadcast();
    }

    function _deployBridge(address owner_, Facets memory facets_) internal returns (address) {
        // Deploy diamond
        address bridge_ = address(new BridgeDiamond(owner_, facets_.diamondCut));

        /// @dev Cut the deposit facet alone to initialize it.
        IDiamondCut.FacetCut[] memory depositCut_ = new IDiamondCut.FacetCut[](1);
        // Deposit facet.
        bytes4[] memory depositFacet_Selectors_ = new bytes4[](7);
        depositFacet_Selectors_[0] = IDepositFacet.setDepositExpirationTimeout.selector;
        depositFacet_Selectors_[1] = IDepositFacet.lockDeposit.selector;
        depositFacet_Selectors_[2] = IDepositFacet.claimDeposit.selector;
        depositFacet_Selectors_[3] = IDepositFacet.reclaimDeposit.selector;
        depositFacet_Selectors_[4] = IDepositFacet.getDeposit.selector;
        depositFacet_Selectors_[5] = IDepositFacet.getPendingDeposits.selector;
        depositFacet_Selectors_[6] = IDepositFacet.getDepositExpirationTimeout.selector;
        depositCut_[0] = IDiamondCut.FacetCut({
            facetAddress: facets_.deposit,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: depositFacet_Selectors_
        });
        bytes memory depositInitializer = abi.encodeWithSelector(
            IDepositFacet.setDepositExpirationTimeout.selector, Constants.DEPOSIT_ONCHAIN_EXPIRATION_TIMEOUT
        );
        IDiamondCut(bridge_).diamondCut(depositCut_, facets_.deposit, depositInitializer);

        /// @dev Cut the withdrawal facet alone to initialize it.
        IDiamondCut.FacetCut[] memory withdrawalCut_ = new IDiamondCut.FacetCut[](1);
        /// Withdrawal facet.
        bytes4[] memory withdrawalFacet_Selectors_ = new bytes4[](7);
        withdrawalFacet_Selectors_[0] = IWithdrawalFacet.setWithdrawalExpirationTimeout.selector;
        withdrawalFacet_Selectors_[1] = IWithdrawalFacet.lockWithdrawal.selector;
        withdrawalFacet_Selectors_[2] = IWithdrawalFacet.claimWithdrawal.selector;
        withdrawalFacet_Selectors_[3] = IWithdrawalFacet.reclaimWithdrawal.selector;
        withdrawalFacet_Selectors_[4] = IWithdrawalFacet.getWithdrawal.selector;
        withdrawalFacet_Selectors_[5] = IWithdrawalFacet.getPendingWithdrawals.selector;
        withdrawalFacet_Selectors_[6] = IWithdrawalFacet.getWithdrawalExpirationTimeout.selector;
        withdrawalCut_[0] = IDiamondCut.FacetCut({
            facetAddress: facets_.withdrawal,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: withdrawalFacet_Selectors_
        });
        bytes memory withdrawalInitializer = abi.encodeWithSelector(
            IWithdrawalFacet.setWithdrawalExpirationTimeout.selector, Constants.WITHDRAWAL_ONCHAIN_EXPIRATION_TIMEOUT
        );
        IDiamondCut(bridge_).diamondCut(withdrawalCut_, facets_.withdrawal, withdrawalInitializer);

        /// @dev cut access control, token register, state and ERC165 facets.
        IDiamondCut.FacetCut[] memory cut_ = new IDiamondCut.FacetCut[](4);

        // Access Control facet.
        bytes4[] memory accessControlFacet_Selectors_ = new bytes4[](3);
        accessControlFacet_Selectors_[0] = IAccessControlFacet.acceptRole.selector;
        accessControlFacet_Selectors_[1] = IAccessControlFacet.setPendingRole.selector;
        accessControlFacet_Selectors_[2] = IAccessControlFacet.getRole.selector;
        cut_[0] = IDiamondCut.FacetCut({
            facetAddress: facets_.accessControl,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: accessControlFacet_Selectors_
        });

        // Token Register facet
        bytes4[] memory tokenRegisterFacet_Selectors_ = new bytes4[](2);
        tokenRegisterFacet_Selectors_[0] = ITokenRegisterFacet.setTokenRegister.selector;
        tokenRegisterFacet_Selectors_[1] = ITokenRegisterFacet.isTokenRegistered.selector;
        cut_[1] = IDiamondCut.FacetCut({
            facetAddress: facets_.tokenRegister,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: tokenRegisterFacet_Selectors_
        });

        // State facet
        bytes4[] memory stateFacet_Selectors_ = new bytes4[](2);
        stateFacet_Selectors_[0] = IStateFacet.getOrderRoot.selector;
        stateFacet_Selectors_[1] = IStateFacet.setOrderRoot.selector;
        cut_[2] = IDiamondCut.FacetCut({
            facetAddress: facets_.state,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: stateFacet_Selectors_
        });

        // State facet
        bytes4[] memory erc165Facet_Selectors_ = new bytes4[](2);
        erc165Facet_Selectors_[0] = IERC165Facet.supportsInterface.selector;
        erc165Facet_Selectors_[1] = IERC165Facet.setSupportedInterface.selector;
        cut_[3] = IDiamondCut.FacetCut({
            facetAddress: facets_.erc165,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc165Facet_Selectors_
        });

        /// Cut diamond finalize.
        IDiamondCut(bridge_).diamondCut(cut_, address(0), "");

        // Add ERC165 interfaces
        IERC165Facet(bridge_).setSupportedInterface(type(IERC165).interfaceId, true);
        IERC165Facet(bridge_).setSupportedInterface(type(IDiamondCut).interfaceId, true);
        IERC165Facet(bridge_).setSupportedInterface(type(IDiamondLoupe).interfaceId, true);

        return bridge_;
    }
}