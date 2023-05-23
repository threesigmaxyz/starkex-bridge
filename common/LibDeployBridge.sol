//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC165 } from "@openzeppelin/interfaces/IERC165.sol";

import { Constants } from "src/constants/Constants.sol";

import { BridgeDiamond } from "src/BridgeDiamond.sol";

import { IDiamondCut } from "src/interfaces/facets/IDiamondCut.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IDepositFacet } from "src/interfaces/facets/IDepositFacet.sol";
import { ITokenRegisterFacet } from "src/interfaces/facets/ITokenRegisterFacet.sol";
import { IWithdrawalFacet } from "src/interfaces/facets/IWithdrawalFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { IERC165Facet } from "src/interfaces/facets/IERC165Facet.sol";
import { INFTFacet } from "src/interfaces/facets/INFTFacet.sol";
import { IDiamondLoupe } from "src/interfaces/facets/IDiamondLoupe.sol";

import { AccessControlFacet } from "src/facets/AccessControlFacet.sol";
import { DepositFacet } from "src/facets/DepositFacet.sol";
import { DiamondCutFacet } from "src/facets/DiamondCutFacet.sol";
import { TokenRegisterFacet } from "src/facets/TokenRegisterFacet.sol";
import { WithdrawalFacet } from "src/facets/WithdrawalFacet.sol";
import { StateFacet } from "src/facets/StateFacet.sol";
import { ERC165Facet } from "src/facets/ERC165Facet.sol";
import { NFTFacet } from "src/facets/NFTFacet.sol";
import { DiamondLoupeFacet } from "src/facets/DiamondLoupeFacet.sol";

library LibDeployBridge {
    struct Facets {
        address accessControl;
        address deposit;
        address diamondCut;
        address tokenRegister;
        address withdrawal;
        address state;
        address erc165;
        address nft;
        address diamondLoupe;
    }

    function deployBridge(address owner_) internal returns (address) {
        Facets memory facets_ = createFacets();
        // Deploy diamond
        address bridge_ = address(new BridgeDiamond(owner_, facets_.diamondCut));
        addFacetsToBridge(bridge_, facets_);
        return bridge_;
    }

    function createFacets() internal returns (Facets memory) {
        Facets memory facets_;
        facets_.accessControl = address(new AccessControlFacet());
        facets_.deposit = address(new DepositFacet());
        facets_.diamondCut = address(new DiamondCutFacet());
        facets_.tokenRegister = address(new TokenRegisterFacet());
        facets_.withdrawal = address(new WithdrawalFacet());
        facets_.state = address(new StateFacet());
        facets_.erc165 = address(new ERC165Facet());
        facets_.nft = address(new NFTFacet());
        facets_.diamondLoupe = address(new DiamondLoupeFacet());
        return facets_;
    }

    function addFacetsToBridge(address bridge_, Facets memory facets_) internal {
        changeBridgeFacets(bridge_, facets_, IDiamondCut.FacetCutAction.Add);
    }

    function changeBridgeFacets(address bridge_, Facets memory facets_, IDiamondCut.FacetCutAction action_) internal {
        // Cut the deposit facet alone to initialize it.
        IDiamondCut.FacetCut[] memory depositCut_ = new IDiamondCut.FacetCut[](1);
        // Deposit facet.
        depositCut_[0] = IDiamondCut.FacetCut({
            facetAddress: facets_.deposit,
            action: action_,
            functionSelectors: getDepositFacetFunctionSelectors()
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
            functionSelectors: getWithdrawalFacetFunctionSelectors()
        });
        bytes memory withdrawalInitializer = abi.encodeWithSelector(
            IWithdrawalFacet.setWithdrawalExpirationTimeout.selector, Constants.WITHDRAWAL_ONCHAIN_EXPIRATION_TIMEOUT
        );
        IDiamondCut(bridge_).diamondCut(withdrawalCut_, facets_.withdrawal, withdrawalInitializer);

        /// @dev Cut the NFT facet alone to initialize it.
        IDiamondCut.FacetCut[] memory nftCut_ = new IDiamondCut.FacetCut[](1);
        /// NFT facet.
        nftCut_[0] = IDiamondCut.FacetCut({
            facetAddress: facets_.nft,
            action: action_,
            functionSelectors: getNFTFacetFunctionSelectors()
        });
        bytes memory nftInitializer = abi.encodeWithSelector(
            INFTFacet.setExpirationTimeout.selector, Constants.DEPOSIT_ONCHAIN_EXPIRATION_TIMEOUT
        );
        IDiamondCut(bridge_).diamondCut(nftCut_, facets_.nft, nftInitializer);

        /// @dev cut access control, token register, state and ERC165 facets.
        IDiamondCut.FacetCut[] memory cut_ = new IDiamondCut.FacetCut[](5);

        // Access Control facet.
        cut_[0] = IDiamondCut.FacetCut({
            facetAddress: facets_.accessControl,
            action: action_,
            functionSelectors: getAccessControlFacetFunctionSelectors()
        });

        // Token Register facet
        cut_[1] = IDiamondCut.FacetCut({
            facetAddress: facets_.tokenRegister,
            action: action_,
            functionSelectors: getTokenRegisterFacetFunctionSelectors()
        });

        // State facet
        cut_[2] = IDiamondCut.FacetCut({
            facetAddress: facets_.state,
            action: action_,
            functionSelectors: getStateFacetFunctionSelectors()
        });

        // State facet
        cut_[3] = IDiamondCut.FacetCut({
            facetAddress: facets_.erc165,
            action: action_,
            functionSelectors: getErc165FacetFunctionSelectors()
        });

        // Diamond Loup facet
        cut_[4] = IDiamondCut.FacetCut({
            facetAddress: facets_.diamondLoupe,
            action: action_,
            functionSelectors: getDiamondLoupeFacetFunctionSelectors()
        });

        /// Cut diamond finalize.
        IDiamondCut(bridge_).diamondCut(cut_, address(0), "");

        // Add ERC165 interfaces
        IERC165Facet(bridge_).setSupportedInterface(type(IERC165).interfaceId, true);
        IERC165Facet(bridge_).setSupportedInterface(type(IDiamondCut).interfaceId, true);
        IERC165Facet(bridge_).setSupportedInterface(type(IDiamondLoupe).interfaceId, true);
    }

    function getDepositFacetFunctionSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory depositFacetSelectors_ = new bytes4[](9);
        depositFacetSelectors_[0] = IDepositFacet.setDepositExpirationTimeout.selector;
        depositFacetSelectors_[1] = IDepositFacet.lockDeposit.selector;
        depositFacetSelectors_[2] = IDepositFacet.lockNativeDeposit.selector;
        depositFacetSelectors_[3] = IDepositFacet.claimDeposit.selector;
        depositFacetSelectors_[4] = IDepositFacet.claimDeposits.selector;
        depositFacetSelectors_[5] = IDepositFacet.reclaimDeposit.selector;
        depositFacetSelectors_[6] = IDepositFacet.getDeposit.selector;
        depositFacetSelectors_[7] = IDepositFacet.getPendingDeposits.selector;
        depositFacetSelectors_[8] = IDepositFacet.getDepositExpirationTimeout.selector;
        return depositFacetSelectors_;
    }

    function getWithdrawalFacetFunctionSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory withdrawalFacetSelectors_ = new bytes4[](8);
        withdrawalFacetSelectors_[0] = IWithdrawalFacet.setWithdrawalExpirationTimeout.selector;
        withdrawalFacetSelectors_[1] = IWithdrawalFacet.lockWithdrawal.selector;
        withdrawalFacetSelectors_[2] = IWithdrawalFacet.lockNativeWithdrawal.selector;
        withdrawalFacetSelectors_[3] = IWithdrawalFacet.claimWithdrawal.selector;
        withdrawalFacetSelectors_[4] = IWithdrawalFacet.reclaimWithdrawal.selector;
        withdrawalFacetSelectors_[5] = IWithdrawalFacet.getWithdrawal.selector;
        withdrawalFacetSelectors_[6] = IWithdrawalFacet.getPendingWithdrawals.selector;
        withdrawalFacetSelectors_[7] = IWithdrawalFacet.getWithdrawalExpirationTimeout.selector;
        return withdrawalFacetSelectors_;
    }

    function getAccessControlFacetFunctionSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory accessControlFacetSelectors_ = new bytes4[](3);
        accessControlFacetSelectors_[0] = IAccessControlFacet.acceptRole.selector;
        accessControlFacetSelectors_[1] = IAccessControlFacet.setPendingRole.selector;
        accessControlFacetSelectors_[2] = IAccessControlFacet.getRole.selector;
        return accessControlFacetSelectors_;
    }

    function getTokenRegisterFacetFunctionSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory tokenRegisterFacetSelectors_ = new bytes4[](2);
        tokenRegisterFacetSelectors_[0] = ITokenRegisterFacet.setTokenRegister.selector;
        tokenRegisterFacetSelectors_[1] = ITokenRegisterFacet.isTokenRegistered.selector;
        return tokenRegisterFacetSelectors_;
    }

    function getStateFacetFunctionSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory stateFacetSelectors_ = new bytes4[](2);
        stateFacetSelectors_[0] = IStateFacet.getOrderRoot.selector;
        stateFacetSelectors_[1] = IStateFacet.setOrderRoot.selector;
        return stateFacetSelectors_;
    }

    function getErc165FacetFunctionSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory erc165FacetSelectors_ = new bytes4[](2);
        erc165FacetSelectors_[0] = IERC165Facet.supportsInterface.selector;
        erc165FacetSelectors_[1] = IERC165Facet.setSupportedInterface.selector;
        return erc165FacetSelectors_;
    }

    function getNFTFacetFunctionSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory nftFacetSelectors_ = new bytes4[](9);
        nftFacetSelectors_[0] = INFTFacet.setExpirationTimeout.selector;
        nftFacetSelectors_[1] = INFTFacet.depositNFT.selector;
        nftFacetSelectors_[2] = INFTFacet.reClaimNFT.selector;
        nftFacetSelectors_[3] = INFTFacet.unlockNFTBurn.selector;
        nftFacetSelectors_[4] = INFTFacet.setRecipientNFT.selector;
        nftFacetSelectors_[5] = INFTFacet.unlockNFTWithdraw.selector;
        nftFacetSelectors_[6] = INFTFacet.withdrawNFT.selector;
        nftFacetSelectors_[7] = INFTFacet.getDepositedNFT.selector;
        nftFacetSelectors_[8] = INFTFacet.getExpirationTimeout.selector;
        return nftFacetSelectors_;
    }

    function getDiamondLoupeFacetFunctionSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory diamondLoupeFacetSelectors_ = new bytes4[](4);
        diamondLoupeFacetSelectors_[0] = IDiamondLoupe.facets.selector;
        diamondLoupeFacetSelectors_[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        diamondLoupeFacetSelectors_[2] = IDiamondLoupe.facetAddresses.selector;
        diamondLoupeFacetSelectors_[3] = IDiamondLoupe.facetAddress.selector;
        return diamondLoupeFacetSelectors_;
    }
}