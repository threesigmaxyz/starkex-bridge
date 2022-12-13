// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibMPT as MerklePatriciaTree } from "src/dependencies/mpt/v2/LibMPT.sol";

import { Modifiers }    from "src/Modifiers.sol";
import { Constants } from "src/constants/Constants.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";
import { HelpersERC20 } from "src/helpers/HelpersERC20.sol";
import { IDepositFacet } from "src/interfaces/IDepositFacet.sol";
import { AppStorage }    from "src/storage/AppStorage.sol";

/**
	Step 1: The user locks their funds in the sidechain account in the interoperability
	contract. These funds are coupled to specific transfer request parameters on StarkEx,
	which would transfer money to the user’s Vault.

	Step 2: The Operator executes the transfer request in Fig. 5 step 1 within StarkEx,
	releasing the funds to the user’s StarkEx Vault. The user may start trading these
	funds immediately.

	Step 3: The transfer from step 2 is batched with other transactions (Fig. 5 step 3.1).
	StarkEx proves to L1 that these transactions happened (step 3.2), and the on-chain
	state is updated accordingly (step 3.3).

	Step 4: A dedicated contract on Ethereum transmits the new L1 state to the interoperability
	contract in the sidechain. This state, i.e., the Merkle root of all the transactions on
	StarkEx, confirms that the user received the funds on StarkEx as requested.

	Step 5: The App opens the Merkle Tree commitment to prove to the sidechain that the user
	indeed received funds on StarkEx in Fig. 5 step 2, unlocking the funds in the
	interoperability contract for the App.

	Fallback flow: if the App fails to complete Fig. 5 step 5 within a limited timeframe, the
	user can reclaim the funds on the sidechain from the interoperability contract.
*/
contract DepositFacet is Modifiers, IDepositFacet {
	//==============================================================================//
    //=== Errors                                                                 ===//
    //==============================================================================//

	// stateless errors
	error InvalidDepositLockError(uint256 lock);
	error InvalidStarkKeyError(uint256 starkKey);
	error InvalidDepositAmountError(uint256 amount);
	// statefull errors
	error DepositPendingError(uint256 lockHash);
    error DepositNotFoundError(uint256 lockHash);
	error DepositNotExpiredError(uint256 lockHash, uint256 expiration);

	//==============================================================================//
    //=== State Variables                                                        ===//
    //==============================================================================//

    AppStorage.AppStorage s;

	//==============================================================================//
    //=== Write API		                                                         ===//
    //==============================================================================//

	/// @inheritdoc IDepositFacet
	function lockDeposit(
		uint256 starkKey_,
		address asset_,
		uint256 amount_,
		uint256 lockHash_
	) external override onlyRegisteredAsset(asset_) {
		// stateless argument validation
		if (starkKey_ == 0 || starkKey_ >= Constants.K_MODULUS || !isOnCurve(starkKey_)) {
			revert InvalidStarkKeyError(starkKey_);
		}
		if (amount_ == 0) revert InvalidDepositAmountError(amount_);
		if (lockHash_ == 0) revert InvalidDepositLockError(lockHash_);

		// check if the deposit is already pending
		if (s.deposits[lockHash_].starkKey != 0) revert DepositPendingError(lockHash_);

		// register the deposit
		s.deposits[lockHash_] = AppStorage.Deposit({
			receiver: msg.sender,
            starkKey: starkKey_,
            asset: asset_,
            amount: amount_,
            expirationDate: (block.timestamp + Constants.DEPOSIT_ONCHAIN_EXPIRATION_TIMEOUT)
        });
		// increment the pending deposit amount for the asset
		s.pendingDeposits[asset_] += amount_;

		// emit event
        emit LogLockDeposit(lockHash_, starkKey_, asset_, amount_);

		// transfer deposited funds to the contract
        HelpersERC20.transferFrom(asset_, msg.sender, address(this), amount_);
	}

	/// @inheritdoc IDepositFacet
	function claimDeposit(
		uint256 lockHash_,
		uint256 branchMask_,
		bytes32[] memory proof_,
		address recipient_
	) external override onlyStarkExOperator {
		// stateless validation
        if (lockHash_ == 0) revert InvalidDepositLockError(lockHash_);

		AppStorage.Deposit memory deposit_ = s.deposits[lockHash_];
		if (deposit_.expirationDate == 0) {
            revert DepositNotFoundError(lockHash_);
        }

		// validate MPT proof
		MerklePatriciaTree.verifyProof(
			bytes32(s.orderRoot),
			abi.encode(lockHash_),
			abi.encode(1),
			branchMask_,
			proof_
		);

		// state update
        delete s.deposits[lockHash_];
        s.pendingDeposits[deposit_.asset] -= deposit_.amount;

		// emit event
		emit LogClaimDeposit(lockHash_, recipient_);

		// Transfer funds
        HelpersERC20.transfer(deposit_.asset, recipient_, deposit_.amount);
	}

	/// @inheritdoc IDepositFacet
    function reclaimDeposit(uint256 lockHash_) external override {
		// stateless validation
		if (lockHash_ == 0) revert InvalidDepositLockError(lockHash_);

		// check if deposit exists and is expired
		AppStorage.Deposit memory deposit_ = s.deposits[lockHash_];
		if (deposit_.expirationDate == 0) {
            revert DepositNotFoundError(lockHash_);
        } else if (block.timestamp <= deposit_.expirationDate) {
			revert DepositNotExpiredError(lockHash_, deposit_.expirationDate);
		}

		// state update
        delete s.deposits[lockHash_];
        s.pendingDeposits[deposit_.asset] -= deposit_.amount;

		// emit event
		emit LogReclaimDeposit(lockHash_);

		// transfer funds
        HelpersERC20.transfer(deposit_.asset, deposit_.receiver, deposit_.amount);
	}

	//==============================================================================//
    //=== Read API		                                                         ===//
    //==============================================================================//

	/// @inheritdoc IDepositFacet
    function getDeposit(uint256 hashId_) external view override returns (AppStorage.Deposit memory) {
        return s.deposits[hashId_];
    }

	/// @inheritdoc IDepositFacet
    function getPendingDeposits(address asset_) external view override returns (uint256 _pending) {
		_pending = s.pendingDeposits[asset_];
	}

	//==============================================================================//
    //=== Internal Functions		                                             ===//
    //==============================================================================//

	function isOnCurve(uint256 starkKey_) private view returns (bool) {
        uint256 xCubed_ = mulmod(mulmod(starkKey_, starkKey_, Constants.K_MODULUS), starkKey_, Constants.K_MODULUS);
        return isQuadraticResidue(addmod(addmod(xCubed_, starkKey_, Constants.K_MODULUS), Constants.K_BETA, Constants.K_MODULUS));
    }

    function isQuadraticResidue(uint256 fieldElement_) private view returns (bool) {
        return 1 == fieldPow(fieldElement_, ((Constants.K_MODULUS - 1) / 2));
    }

	function fieldPow(uint256 base, uint256 exponent) internal view returns (uint256) {
        (bool success, bytes memory returndata) = address(5).staticcall(
            abi.encode(0x20, 0x20, 0x20, base, exponent, Constants.K_MODULUS)
        );
        require(success, string(returndata));
        return abi.decode(returndata, (uint256));
    }
}