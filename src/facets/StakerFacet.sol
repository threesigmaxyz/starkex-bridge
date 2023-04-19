// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IStakerFacet } from "src/interfaces/facets/IStakerFacet.sol";
import { HelpersECDSA } from "src/helpers/HelpersECDSA.sol";
import { HelpersERC20 } from "src/helpers/HelpersERC20.sol";
import { HelpersTransferNativeOrERC20 } from "src/helpers/HelpersTransferNativeOrERC20.sol";
import { Constants } from "src/constants/Constants.sol";
import { OnlyRegisteredToken } from "src/modifiers/OnlyRegisteredToken.sol";
import { OnlyOwner } from "src/modifiers/OnlyOwner.sol";
import { ILzTransmitter } from "src/liquidityBridging/interfaces/ILzTransmitter.sol";

contract StakerFacet is OnlyRegisteredToken, OnlyOwner, IStakerFacet {
    bytes32 constant STAKER_STORAGE_POSITION = keccak256("STAKER_STORAGE_POSITION");
    uint16 constant ETHEREUM_CHAIN_ID = 1;

    /// @dev Storage of this facet using diamond storage.
    function stakerStorage() internal pure returns (StakerStorage storage ss) {
        bytes32 position_ = STAKER_STORAGE_POSITION;
        assembly {
            ss.slot := position_
        }
    }

    /// @inheritdoc IStakerFacet
    function registerNativeStaker(address payable staker_, uint256 starkKey_, uint256 vaultId_, uint256 amount_)
        external
        payable
        override
    {
        bytes memory payload_ = abi.encode(starkKey_, vaultId_, Constants.NATIVE, amount_ / 2);

        // Check if staker sent enought to pay for the transmition fee.
        if (msg.value < amount_) revert NotEnoughtFeeError();
        _checkFee(payload_, (msg.value - amount_));

        _validateAndAddStaker(staker_, starkKey_, vaultId_, Constants.NATIVE, amount_);

        // Send message.
        ILzTransmitter(stakerStorage().transmitter).keep{ value: (msg.value - amount_) }(
            ETHEREUM_CHAIN_ID, payload_, staker_
        );
        emit LogStakerMessageSent(payload_, staker_);

        // The native is transferred to the contract, no need to call any transfer function like registerStaker.
    }

    /// @inheritdoc IStakerFacet
    function registerStaker(
        address payable staker_,
        uint256 starkKey_,
        uint256 vaultId_,
        address token_,
        uint256 amount_
    ) external payable override onlyRegisteredToken(token_) {
        bytes memory payload_ = abi.encode(starkKey_, vaultId_, token_, amount_ / 2);

        // Check if staker sent enought to pay for the transmition fee.
        _checkFee(payload_, msg.value);

        _validateAndAddStaker(staker_, starkKey_, vaultId_, token_, amount_);

        // Send message.
        ILzTransmitter(stakerStorage().transmitter).keep{ value: msg.value }(ETHEREUM_CHAIN_ID, payload_, staker_);
        emit LogStakerMessageSent(payload_, staker_);

        // Transfer funds.
        HelpersERC20.transferFrom(token_, msg.sender, address(this), amount_);
    }

    /// @inheritdoc IStakerFacet
    function setTransmitter(address transmitter_) public override onlyOwner {
        stakerStorage().transmitter = transmitter_;
        emit LogSetTransmitter(transmitter_);
    }

    /// @inheritdoc IStakerFacet
    function getTransmitter() external view override returns (address) {
        return stakerStorage().transmitter;
    }

    /// @inheritdoc IStakerFacet
    function getStakerInfo(address addr_, address token_) external view override returns (Staker memory staker_) {
        staker_ = stakerStorage().stakers[abi.encode(addr_, token_)];
        if (staker_.staker == address(0)) revert StakerNotFoundError();
    }

    function _validateAndAddStaker(
        address payable staker_,
        uint256 starkKey_,
        uint256 vaultId_,
        address token_,
        uint256 amount_
    ) internal {
        // Validations
        if (!HelpersECDSA.isOnCurve(starkKey_) || starkKey_ > Constants.K_MODULUS) revert InvalidStarkKeyError();
        if (amount_ == 0) revert ZeroAmountError();
        if (staker_ == address(0)) revert ZeroAddressStakerError();

        StakerStorage storage ss = stakerStorage();

        // Create a staker.
        ss.stakers[abi.encode(staker_, token_)] = Staker({
            staker: staker_,
            starkKey: starkKey_,
            vaultId: vaultId_,
            token: token_,
            amount: amount_ / 2,
            amountLocked: amount_ / 2
        });
    }

    function _checkFee(bytes memory payload_, uint256 amount_) internal view {
        // Get transmition fee.
        (uint256 nativeFee_, uint256 zroFee_) =
            ILzTransmitter(stakerStorage().transmitter).getLayerZeroFee(ETHEREUM_CHAIN_ID, payload_);
        uint256 fee_ = nativeFee_ + zroFee_;

        // Check if enought sent to pay for fee.
        if (amount_ < fee_) revert NotEnoughtFeeError();
    }
}
