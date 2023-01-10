//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { BridgeDiamond } from "src/BridgeDiamond.sol";

import { Constants } from "src/constants/Constants.sol";

import { LibDeployBridge } from "common/LibDeployBridge.sol";

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";

import { LzReceptor } from "src/interoperability/LzReceptor.sol";

import { DataIO } from "script/data/DataIO.sol";

contract DeployBridgeAndReceptorModuleScript is Script, DataIO {

    address public _owner;
    address public _operator;
    address public _tokenAdmin;
    address public _bridge;
    address public _lzEndpoint;

    LzReceptor public _receptor;

    function setUp() public {
        _owner = vm.rememberKey(vm.envUint("OWNER_PRIVATE_KEY"));
        _operator = vm.envAddress("STARKEX_OPERATOR");
        _tokenAdmin = vm.envAddress("TOKEN_ADMIN");
        _lzEndpoint = vm.envAddress("LAYER_ZERO_ENDPOINT");
    }

    function run() external {
        // Record calls and contract creations made by our script contract.
        vm.startBroadcast(_owner);

        // Deploy bridge.
        _bridge = LibDeployBridge.deployBridge(_owner);
        _writeData("bridge", vm.toString(abi.encodePacked((_bridge))));

        // Deploy recepetor
        _receptor = new LzReceptor(_lzEndpoint, _bridge);
        _writeData("receptor", vm.toString(address(_receptor)));

        // Set pending roles.
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.STARKEX_OPERATOR_ROLE, _operator);
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.TOKEN_ADMIN_ROLE, _tokenAdmin);
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE, address(_receptor));

        // Accept interoperability role.
        _receptor.acceptBridgeRole();

        // Stop recording calls.
        vm.stopBroadcast();
    }
}
