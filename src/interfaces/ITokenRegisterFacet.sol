// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenRegisterFacet {
    
    /**
     * TODO
     */
    event LogTokenAdminSet(address admin, bool isValid);

    /**
     * TODO
     */
    event LogTokenRegistered(uint256 assetType, bytes assetInfo, uint256 quantum);

    /**
     * TODO
     */
    function setValidTokenAdmin(address admin_, bool isValid_) external;

    /**
     * TODO
     */
    function registerToken(uint256 assetType_, bytes calldata assetInfo_, uint256 quantum_) external;
}