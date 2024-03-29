// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ECDSA } from "src/dependencies/ecdsa/ECDSA.sol";
import { HelpersECDSA } from "src/helpers/HelpersECDSA.sol";

import { HelpersERC20 } from "src/helpers/HelpersERC20.sol";
import { HelpersTransferNativeOrERC20 } from "src/helpers/HelpersTransferNativeOrERC20.sol";
import { Constants } from "src/constants/Constants.sol";
import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";
import { OnlyOwner } from "src/modifiers/OnlyOwner.sol";
import { OnlyStarkExOperator } from "src/modifiers/OnlyStarkExOperator.sol";
import { OnlyRegisteredToken } from "src/modifiers/OnlyRegisteredToken.sol";
import { IWithdrawalFacet } from "src/interfaces/facets/IWithdrawalFacet.sol";

/**
 * Step 1: The user sends an off-chain request to the App, specifying the amount and
 *     type of token they want to withdraw. The App verifies that the user has sufficient
 *     funds in their StarkEx Vault.
 *
 *     Step 2: The App locks the specified value and type of token in an interoperability
 *     contract found on the sidechain. The App couples these funds against an (unsigned)
 *     StarkEx’s transfer request, which orders StarkEx to transfer the relevant tokens
 *     from the user’s Vault to the App’s Vault.
 *
 *     Step 3: The user signs the transfer request specified at Fig. 4 step 2, activating
 *     the interoperability contract on the sidechain. This transaction immediately unlocks
 *     the user’s funds for use on the sidechain.
 *
 *     Step 4: The App can now execute the transfer request on StarkEx and receive the
 *     user’s funds there.
 *
 *     Fallback flow: if the user fails to sign within a limited time frame, the App reclaims
 *     the money from the interoperability contract.
 */
contract WithdrawalFacet is OnlyRegisteredToken, OnlyStarkExOperator, OnlyOwner, IWithdrawalFacet {
    bytes32 constant WITHDRAW_STORAGE_POSITION = keccak256("WITHDRAW_STORAGE_POSITION");

    /// @dev Storage of this facet using diamond storage.
    function withdrawalStorage() internal pure returns (WithdrawalStorage storage ws) {
        bytes32 position_ = WITHDRAW_STORAGE_POSITION;
        assembly {
            ws.slot := position_
        }
    }

    //==============================================================================//
    //=== Write API		                                                         ===//
    //==============================================================================//

    /// @inheritdoc IWithdrawalFacet
    function setWithdrawalExpirationTimeout(uint256 timeout_) public override onlyOwner {
        withdrawalStorage().withdrawalExpirationTimeout = timeout_;
        emit LogSetWithdrawalExpirationTimeout(timeout_);
    }

    /// @inheritdoc IWithdrawalFacet
    function lockNativeWithdrawal(uint256 starkKey_, uint256 lockHash_, address recipient_)
        external
        payable
        override
        onlyStarkExOperator
    {
        _validateAndAddWithdrawal(starkKey_, Constants.NATIVE, msg.value, lockHash_, recipient_);
        // The native is transferred to the contract, no need to call any transfer function like lockDeposit
    }

    /// @inheritdoc IWithdrawalFacet
    function lockWithdrawal(uint256 starkKey_, address token_, uint256 amount_, uint256 lockHash_, address recipient_)
        external
        override
        onlyStarkExOperator
        onlyRegisteredToken(token_)
    {
        _validateAndAddWithdrawal(starkKey_, token_, amount_, lockHash_, recipient_);

        // Transfer funds.
        HelpersERC20.transferFrom(token_, msg.sender, address(this), amount_);
    }

    /// @inheritdoc IWithdrawalFacet
    function claimWithdrawal(uint256 lockHash_, bytes memory signature_) external override {
        // Stateless validation.
        if (lockHash_ == 0) revert InvalidLockHashError();
        if (signature_.length != 32 * 3) revert InvalidSignatureError();

        WithdrawalStorage storage ws = withdrawalStorage();

        Withdrawal memory withdrawal_ = ws.withdrawals[lockHash_];
        if (withdrawal_.expirationDate == 0) revert WithdrawalNotFoundError();

        // Statefull signature validation.
        (uint256 r_, uint256 s_, uint256 starkKeyY_) = abi.decode(signature_, (uint256, uint256, uint256));
        ECDSA.verify(lockHash_, r_, s_, withdrawal_.starkKey, starkKeyY_);

        // State update.
        delete ws.withdrawals[lockHash_];
        ws.pendingWithdrawals[withdrawal_.token] -= withdrawal_.amount;

        // Emit event.
        emit LogClaimWithdrawal(lockHash_, signature_, withdrawal_.recipient);

        // Transfer funds.
        HelpersTransferNativeOrERC20.transfer(withdrawal_.token, withdrawal_.recipient, withdrawal_.amount);
    }

    /// @inheritdoc IWithdrawalFacet
    function reclaimWithdrawal(uint256 lockHash_, address recipient_) external override onlyStarkExOperator {
        // Stateless validation.
        if (lockHash_ == 0) revert InvalidLockHashError();
        if (recipient_ == address(0)) revert ZeroAddressRecipientError();

        WithdrawalStorage storage ws = withdrawalStorage();

        Withdrawal memory withdrawal_ = ws.withdrawals[lockHash_];
        if (withdrawal_.expirationDate == 0) revert WithdrawalNotFoundError();
        if (block.timestamp <= withdrawal_.expirationDate) revert WithdrawalNotExpiredError();

        // State update.
        delete ws.withdrawals[lockHash_];
        ws.pendingWithdrawals[withdrawal_.token] -= withdrawal_.amount;

        // Emit event.
        emit LogReclaimWithdrawal(lockHash_, recipient_);

        // Transfer funds.
        HelpersTransferNativeOrERC20.transfer(withdrawal_.token, recipient_, withdrawal_.amount);
    }

    //==============================================================================//
    //=== Read API		                                                         ===//
    //==============================================================================//

    /// @inheritdoc IWithdrawalFacet
    function getWithdrawal(uint256 lockHash_) external view override returns (Withdrawal memory withdrawal_) {
        withdrawal_ = withdrawalStorage().withdrawals[lockHash_];
        if (withdrawal_.expirationDate == 0) revert WithdrawalNotFoundError();
    }

    /// @inheritdoc IWithdrawalFacet
    function getPendingWithdrawals(address token_) external view override returns (uint256 pending_) {
        pending_ = withdrawalStorage().pendingWithdrawals[token_];
    }

    /// @inheritdoc IWithdrawalFacet
    function getWithdrawalExpirationTimeout() external view override returns (uint256) {
        return withdrawalStorage().withdrawalExpirationTimeout;
    }

    function _validateAndAddWithdrawal(
        uint256 starkKey_,
        address token_,
        uint256 amount_,
        uint256 lockHash_,
        address recipient_
    ) internal {
        // Validate keys and availability.
        if (lockHash_ == 0) revert InvalidLockHashError();
        if (!HelpersECDSA.isOnCurve(starkKey_) || starkKey_ > Constants.K_MODULUS) revert InvalidStarkKeyError();
        if (amount_ == 0) revert ZeroAmountError();
        if (recipient_ == address(0)) revert ZeroAddressRecipientError();

        WithdrawalStorage storage ws = withdrawalStorage();

        // Create a withdrawal lock for the funds.
        ws.withdrawals[lockHash_] = Withdrawal({
            recipient: recipient_,
            starkKey: starkKey_,
            token: token_,
            amount: amount_,
            expirationDate: (block.timestamp + ws.withdrawalExpirationTimeout)
        });
        ws.pendingWithdrawals[token_] += amount_;

        // Emit new Lock.
        emit LogLockWithdrawal(lockHash_, starkKey_, token_, amount_, recipient_);
    }
}
