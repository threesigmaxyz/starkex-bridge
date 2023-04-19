// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWrappedToken {
    /**
     * @notice Emitts when the StarkEx asset identifiers are set.
     * @param assetInfo The asset info for StarkEx for this token.
     * @param assetType The asset type for StarkEx for this token
     */
    event LogSetAsset(bytes assetInfo, uint256 assetType);

    /**
     * @notice Mint wrapped tokens.
     * @param to Address to mint to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Get asset type.
     * @return The asset type for StarkEx for this token
     */
    function getAssetType() external view returns (uint256);

    /**
     * @notice Get asset info.
     * @return The asset info for StarkEx for this token.
     */
    function getAssetInfo() external view returns (bytes memory);
}
