// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ECDSA } from "src/dependencies/ecdsa/ECDSA.sol";

import { Modifiers }        from "src/Modifiers.sol";
import { Constants }        from "src/constants/Constants.sol";
import { HelpersERC20 }     from "src/helpers/HelpersERC20.sol";
import { IWithdrawalFacet } from "src/interfaces/IWithdrawalFacet.sol";

import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

import { AppStorage }       from "src/storage/AppStorage.sol";

/**
    Step 1: The user sends an off-chain request to the App, specifying the amount and
    type of asset they want to withdraw. The App verifies that the user has sufficient
    funds in their StarkEx Vault.

    Step 2: The App locks the specified value and type of asset in an interoperability
    contract found on the sidechain. The App couples these funds against an (unsigned)
    StarkEx’s transfer request, which orders StarkEx to transfer the relevant assets
    from the user’s Vault to the App’s Vault.
    
    Step 3: The user signs the transfer request specified at Fig. 4 step 2, activating
    the interoperability contract on the sidechain. This transaction immediately unlocks
    the user’s funds for use on the sidechain.

    Step 4: The App can now execute the transfer request on StarkEx and receive the
    user’s funds there.

    Fallback flow: if the user fails to sign within a limited time frame, the App reclaims
    the money from the interoperability contract.
*/
contract WithdrawalFacet is Modifiers, IWithdrawalFacet {
    //==============================================================================//
    //=== Errors                                                                 ===//
    //==============================================================================//

    error WithdrawalNotFoundError(uint256 lockHash);

    //==============================================================================//
    //=== State Variables                                                        ===//
    //==============================================================================//

    AppStorage.AppStorage s;

    //==============================================================================//
    //=== Write API		                                                         ===//
    //==============================================================================//

    /** @dev See {IWithdrawalFacet-lockWithdrawal}. */
    function lockWithdrawal(
        uint256 starkKey_,
        address asset_,
        uint256 amount_,
        uint256 lockHash_
    ) external override onlyStarkExOperator onlyRegisteredAsset(asset_) {
        // TODO require(userWithdrawLock[receiver].expirationDate == 0, "EXISTS LOCK");
        // Validate keys and availability.
        require(lockHash_ != 0, "INVALID_LOCK_HASH");
        require(starkKey_ != 0, "INVALID_STARK_KEY");
        require(starkKey_ < Constants.K_MODULUS, "INVALID_STARK_KEY");
        // TODO require(StarkKeyVerifier.isOnCurve(starkKey_), "INVALID_STARK_KEY");
        require(amount_ > 0, 'WF:LF:NOP');

        // Create a withdrawal lock for the funds
        s.withdrawals[lockHash_] = AppStorage.Withdrawal({
            starkKey: starkKey_,
            asset: asset_,
            amount: amount_,
            expirationDate: (block.timestamp + Constants.WITHDRAWAL_ONCHAIN_EXPIRATION_TIMEOUT)
        });
        s.pendingWithdrawals[asset_] += amount_;

        // Transfer funds
        HelpersERC20.transferFrom(asset_, msg.sender, address(this), amount_);  // TODO is this safe?
        
        // emit new Lock
        emit LogLockWithdrawal(lockHash_, starkKey_, asset_, amount_);
    }

    /** @dev See {IWithdrawalFacet-claimWithdrawal}. */
    function claimWithdrawal(
        uint256 lockHash_,
        bytes memory signature_,        // TODO make calldata? hard to test...
        address recipient_
    ) external override {
        // stateless validation
        require(lockHash_ != 0, "INVALID_LOCK_HASH");
        require(signature_.length == 32 * 3, "INVALID_LENGTH");
        require(recipient_ != address(0), "INVALID_RECIPIENT");

        AppStorage.Withdrawal memory withdrawal_ = s.withdrawals[lockHash_];
        if (withdrawal_.expirationDate == 0) {
            revert WithdrawalNotFoundError(lockHash_);
        }

        // statefull signature validation
        (uint256 r_, uint256 s_, uint256 starkKeyY_) = abi.decode(signature_, (uint256, uint256, uint256));
        ECDSA.verify(lockHash_, r_, s_, withdrawal_.starkKey, starkKeyY_);

        // state update
        delete s.withdrawals[lockHash_];
        s.pendingWithdrawals[withdrawal_.asset] -= withdrawal_.amount;

        // emit event
        emit LogClaimWithdrawal(lockHash_, recipient_);

        // transfer funds
        HelpersERC20.transfer(withdrawal_.asset, recipient_, withdrawal_.amount);
    }

    /** @dev See {IWithdrawalFacet-reclaimWithdrawal}. */
    function reclaimWithdrawal(
        uint256 lockHash_,
        address recipient_
    ) external override onlyStarkExOperator {
        // stateless validation
        require(lockHash_ != 0, "INVALID_LOCK_HASH");
        require(recipient_ != address(0), "INVALID_RECIPIENT");

        AppStorage.Withdrawal memory withdrawal_ = s.withdrawals[lockHash_];
        require(withdrawal_.expirationDate > 0 && block.timestamp > withdrawal_.expirationDate, 'CANT_UNLOCK');

        // state update
        delete s.withdrawals[lockHash_];
        s.pendingWithdrawals[withdrawal_.asset] -= withdrawal_.amount;

        // emit event
        emit LogReclaimWithdrawal(lockHash_, recipient_);

        // transfer funds
        HelpersERC20.transfer(withdrawal_.asset, recipient_, withdrawal_.amount);
    }

    //==============================================================================//
    //=== Read API		                                                         ===//
    //==============================================================================//

    /** @dev See {IWithdrawalFacet-getWithdrawal}. */
    function getWithdrawal(uint256 hashId_) external view override returns (AppStorage.Withdrawal memory withdrawal_) {
        withdrawal_ = s.withdrawals[hashId_];
    }

    /** @dev See {IWithdrawalFacet-getPendingWithdrawals}. */
    function getPendingWithdrawals(address asset_) external view override returns (uint256 pending_) {
        pending_ = s.pendingWithdrawals[asset_];
    }
}