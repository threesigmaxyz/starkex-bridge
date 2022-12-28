// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Constants} from "src/constants/Constants.sol";
import {LibMPT as MerklePatriciaTree} from "src/dependencies/mpt/v2/LibMPT.sol";
import {HelpersERC20} from "src/helpers/HelpersERC20.sol";
import {HelpersECDSA} from "src/helpers/HelpersECDSA.sol";
import {LibState} from "src/libraries/LibState.sol";
import {OnlyOwner} from "src/modifiers/OnlyOwner.sol";
import {OnlyStarkExOperator} from "src/modifiers/OnlyStarkExOperator.sol";
import {OnlyRegisteredToken} from "src/modifiers/OnlyRegisteredToken.sol";
import {IDepositFacet} from "src/interfaces/facets/IDepositFacet.sol";

/**
 * Step 1: The user locks their funds in the sidechain account in the interoperability
 * 	contract. These funds are coupled to specific transfer request parameters on StarkEx,
 * 	which would transfer money to the user’s Vault.
 *
 * 	Step 2: The Operator executes the transfer request in Fig. 5 step 1 within StarkEx,
 * 	releasing the funds to the user’s StarkEx Vault. The user may start trading these
 * 	funds immediately.
 *
 * 	Step 3: The transfer from step 2 is batched with other transactions (Fig. 5 step 3.1).
 * 	StarkEx proves to L1 that these transactions happened (step 3.2), and the on-chain
 * 	state is updated accordingly (step 3.3).
 *
 * 	Step 4: A dedicated contract on Ethereum transmits the new L1 state to the interoperability
 * 	contract in the sidechain. This state, i.e., the Merkle root of all the transactions on
 * 	StarkEx, confirms that the user received the funds on StarkEx as requested.
 *
 * 	Step 5: The App opens the Merkle Tree commitment to prove to the sidechain that the user
 * 	indeed received funds on StarkEx in Fig. 5 step 2, unlocking the funds in the
 * 	interoperability contract for the App.
 *
 * 	Fallback flow: if the App fails to complete Fig. 5 step 5 within a limited timeframe, the
 * 	user can reclaim the funds on the sidechain from the interoperability contract.
 */
contract DepositFacet is
    OnlyRegisteredToken,
    OnlyStarkExOperator,
    OnlyOwner,
    IDepositFacet
{
    bytes32 constant DEPOSIT_STORAGE_POSITION =
        keccak256("DEPOSIT_STORAGE_POSITION");

    /// @dev Storage of this facet using diamond storage.
    function depositStorage()
        internal
        pure
        returns (DepositStorage storage ds)
    {
        bytes32 position_ = DEPOSIT_STORAGE_POSITION;
        assembly {
            ds.slot := position_
        }
    }

    //==============================================================================//
    //=== Write API		                                                         ===//
    //==============================================================================//

    /// @inheritdoc IDepositFacet
    function setDepositExpirationTimeout(uint256 timeout_)
        public
        override
        onlyOwner
    {
        depositStorage().depositExpirationTimeout = timeout_;
        emit LogSetDepositExpirationTimeout(timeout_);
    }

    /// @inheritdoc IDepositFacet
    function lockDeposit(
        uint256 starkKey_,
        address token_,
        uint256 amount_,
        uint256 lockHash_
    ) external override onlyRegisteredToken(token_) {
        // Stateless argument validation.
        if (
            !HelpersECDSA.isOnCurve(starkKey_) ||
            starkKey_ > Constants.K_MODULUS
        ) revert InvalidStarkKeyError();
        if (amount_ == 0) revert ZeroAmountError();
        if (lockHash_ == 0) revert InvalidDepositLockError();

        DepositStorage storage ds = depositStorage();

        // Check if the deposit is already pending.
        if (ds.deposits[lockHash_].expirationDate != 0)
            revert DepositPendingError();

        // Register the deposit.
        ds.deposits[lockHash_] = Deposit({
            receiver: msg.sender,
            starkKey: starkKey_,
            token: token_,
            amount: amount_,
            expirationDate: (block.timestamp + ds.depositExpirationTimeout)
        });
        // Increment the pending deposit amount for the token.
        ds.pendingDeposits[token_] += amount_;

        // Emit event.
        emit LogLockDeposit(lockHash_, starkKey_, token_, amount_);

        // Transfer deposited funds to the contract.
        HelpersERC20.transferFrom(token_, msg.sender, address(this), amount_);
    }

    /// @inheritdoc IDepositFacet
    function claimDeposit(
        uint256 lockHash_,
        uint256 branchMask_,
        bytes32[] memory proof_,
        address recipient_
    ) external override onlyStarkExOperator {
        // Stateless validation.
        if (lockHash_ == 0) revert InvalidDepositLockError();
        if (recipient_ == address(0)) revert ZeroAddressRecipientError();

        DepositStorage storage ds = depositStorage();

        Deposit memory deposit_ = ds.deposits[lockHash_];
        if (deposit_.expirationDate == 0) revert DepositNotFoundError();

        // Validate MPT proof.
        MerklePatriciaTree.verifyProof(
            bytes32(LibState.getOrderRoot()),
            abi.encode(lockHash_),
            abi.encode(1),
            branchMask_,
            proof_
        );

        // State update.
        delete ds.deposits[lockHash_];
        ds.pendingDeposits[deposit_.token] -= deposit_.amount;

        // Emit event.
        emit LogClaimDeposit(lockHash_, recipient_);

        // Transfer funds
        HelpersERC20.transfer(deposit_.token, recipient_, deposit_.amount);
    }

    /// @inheritdoc IDepositFacet
    function reclaimDeposit(uint256 lockHash_) external override {
        // Stateless validation.
        if (lockHash_ == 0) revert InvalidDepositLockError();

        DepositStorage storage ds = depositStorage();

        Deposit memory deposit_ = ds.deposits[lockHash_];
        // Check if deposit exists or has expired.
        if (deposit_.expirationDate == 0) revert DepositNotFoundError();
        if (block.timestamp <= deposit_.expirationDate)
            revert DepositNotExpiredError();

        // State update.
        delete ds.deposits[lockHash_];
        ds.pendingDeposits[deposit_.token] -= deposit_.amount;

        // Emit event.
        emit LogReclaimDeposit(lockHash_);

        // Transfer funds.
        HelpersERC20.transfer(
            deposit_.token,
            deposit_.receiver,
            deposit_.amount
        );
    }

    //==============================================================================//
    //=== Read API		                                                         ===//
    //==============================================================================//

    /// @inheritdoc IDepositFacet
    function getDeposit(uint256 lockHash_)
        external
        view
        override
        returns (Deposit memory deposit)
    {
        deposit = depositStorage().deposits[lockHash_];
        if (deposit.expirationDate == 0) revert DepositNotFoundError();
    }

    /// @inheritdoc IDepositFacet
    function getPendingDeposits(address token_)
        external
        view
        override
        returns (uint256)
    {
        return depositStorage().pendingDeposits[token_];
    }

    /// @inheritdoc IDepositFacet
    function getDepositExpirationTimeout()
        external
        view
        override
        returns (uint256)
    {
        return depositStorage().depositExpirationTimeout;
    }
}
