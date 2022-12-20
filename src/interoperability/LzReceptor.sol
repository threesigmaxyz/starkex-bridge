// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Pausable } from "@openzeppelin/security/Pausable.sol";

import { NonblockingLzApp } from "src/dependencies/lz/NonblockingLzApp.sol";

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

interface IBridge {
    function setOrderRoot(uint256 orderRoot_) external;
    function acceptRole(bytes32 role_) external;
}

contract LzReceptor is NonblockingLzApp, Pausable {
    
    IBridge immutable private _bridge;

    constructor(
        address lzEndpoint_,
        address bridgeAddress_
    ) NonblockingLzApp(lzEndpoint_) {
        _bridge = IBridge(bridgeAddress_);
    }

    function acceptBridgeRole() public {
        _bridge.acceptRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);
    }

    function _nonblockingLzReceive(
        uint16 srcChainId_,
        bytes memory srcAddress_,
        uint64 nonce_,
        bytes memory payload_
    ) internal override {
        // TODO validate srcAddress_
        // TODO validate nonce as sequence number?
        // use assembly to extract the address from the bytes memory parameter
        // address sendBackToAddress;
        // assembly {
        //     sendBackToAddress := mload(add(_srcAddress, 20))
        // }

        // decode the number of pings sent thus far
        (
            uint256 validiumVaultRoot_,
            uint256 validiumTreeHeight_,
            uint256 rollupVaultRoot_,
            uint256 rollupTreeHeight_,
            uint256 orderRoot_,
            uint256 orderTreeHeight_
        ) = abi.decode(payload_, (uint256, uint256, uint256, uint256, uint256, uint256));

        _bridge.setOrderRoot(orderRoot_);
    }
}