// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { WrappedToken } from "src/liquidityBridging/WrappedToken.sol";
import { WrappedTokenFactory } from "src/liquidityBridging/WrappedTokenFactory.sol";
import { IStarkEx } from "src/liquidityBridging/interfaces/IStarkEx.sol";
import { ILzReceptor } from "src/interfaces/interoperability/ILzReceptor.sol";
import { ILiquidityBridge } from "src/liquidityBridging/interfaces/ILiquidityBridge.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract LiquidityBridge is Ownable, ILiquidityBridge {
    /// @notice Address of the starkEx contract.
    IStarkEx private immutable _starkEx;

    /// @notice Address of the receptor contract.
    ILzReceptor private immutable _receptor;

    /// @notice Address of the factory contract.
    WrappedTokenFactory private _tokenFactory;

    /// @notice List of existing wrapped tokens acessable with the address and chainId of the original token.
    mapping(bytes => address) _wrappedTokens;

    constructor(address starkExAddress_, address receptorAddress_) {
        if (starkExAddress_ == address(0)) revert ZeroStarkExAddressError();
        if (receptorAddress_ == address(0)) revert ZeroReceptorAddressError();

        _starkEx = IStarkEx(starkExAddress_);
        _receptor = ILzReceptor(receptorAddress_);
        _tokenFactory = new WrappedTokenFactory();

        emit LogSetStarkExAddress(starkExAddress_);
    }

    /// @inheritdoc ILiquidityBridge
    function mintAndDepositStarkEx(
        uint16 srcChainId_,
        uint256 starkKey_,
        uint256 vaultId_,
        address token_,
        uint256 amount_
    ) external override {
        // Only receptor can call this function.
        if (msg.sender != address(_receptor)) revert NotReceptorError();

        // Get wrapped token to use.
        address wrappedToken_ = _wrappedTokens[abi.encode(srcChainId_, token_)];
        if (wrappedToken_ == address(0)) revert ZeroWrappedTokenError();

        // Mint wrapped tokens.
        WrappedToken(wrappedToken_).mint(address(this), amount_);

        uint256 assetType_ = WrappedToken(wrappedToken_).getAssetType();

        // Deposit in StarkEx
        _starkEx.depositERC20(starkKey_, assetType_, vaultId_, amount_);
        emit LogDepositStarkEx(starkKey_, vaultId_, assetType_, amount_);
    }

    /// @inheritdoc ILiquidityBridge
    function deployAndRegisterWrappedToken(uint16 srcChainId_, address token_, uint256 quantum_)
        external
        override
        onlyOwner
    {
        if (token_ == address(0)) revert ZeroTokenAddressError();

        // Deploy token.
        address wrappedToken_ = _tokenFactory.createWrappedToken(srcChainId_, token_, quantum_);

        // Add wrapped token to list.
        _wrappedTokens[abi.encode(srcChainId_, token_)] = wrappedToken_;
        emit LogAddWrappedToken(srcChainId_, token_, wrappedToken_);

        uint256 assetType_ = WrappedToken(wrappedToken_).getAssetType();
        bytes memory assetInfo_ = WrappedToken(wrappedToken_).getAssetInfo();

        // Register wrapped token in starkEx.
        IStarkEx(_starkEx).registerToken(assetType_, assetInfo_, quantum_);
        emit LogTokenRegistedStarkEx(assetType_, assetInfo_, quantum_);
    }

    /// @inheritdoc ILiquidityBridge
    function getWrappedTokenAddress(uint16 srcChainId_, address token_) external view override returns (address) {
        return _wrappedTokens[abi.encode(srcChainId_, token_)];
    }

    /// @inheritdoc ILiquidityBridge
    function getFactoryAddress() external view override returns (address) {
        return address(_tokenFactory);
    }
}
