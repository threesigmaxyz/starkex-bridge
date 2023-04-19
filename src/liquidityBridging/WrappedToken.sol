// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { IWrappedToken } from "src/liquidityBridging/interfaces/IWrappedToken.sol";

contract WrappedToken is ERC20, ERC20Burnable, Ownable, IWrappedToken {
    /// @notice StarkEx selector for `ERC20` tokens.
    bytes4 internal constant ERC20_SELECTOR = bytes4(keccak256("ERC20Token(address)"));

    /// @notice Bit mask for the first 250 bits.
    /// @dev Used when calculating StarkEx asset types.
    uint256 internal constant MASK_250 = 0x03FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    /// @notice The asset type for StarkEx for this token.
    uint256 private immutable _assetType;

    /// @notice The asset info for StarkEx for this token.
    bytes private _assetInfo;

    constructor(uint256 quantum_) ERC20("WrappedToken", "WT") {
        (bytes memory assetInfo_, uint256 assetType_) = _calcAssetId(quantum_);

        _assetInfo = assetInfo_;
        _assetType = assetType_;

        emit LogSetAsset(assetInfo_, assetType_);
    }

    /// @inheritdoc IWrappedToken
    function mint(address to, uint256 amount) public override onlyOwner {
        _mint(to, amount);
    }

    /// @inheritdoc IWrappedToken
    function getAssetType() external view override returns (uint256) {
        return _assetType;
    }

    /// @inheritdoc IWrappedToken
    function getAssetInfo() external view override returns (bytes memory) {
        return _assetInfo;
    }

    function _calcAssetId(uint256 quantum_) internal view returns (bytes memory, uint256) {
        // Calculate StarkEx asset identifiers.
        bytes memory assetInfo_ = abi.encodePacked(ERC20_SELECTOR, abi.encode(address(this)));
        uint256 assetType_ = uint256(keccak256(abi.encodePacked(assetInfo_, quantum_))) & MASK_250;

        return (assetInfo_, assetType_);
    }
}
