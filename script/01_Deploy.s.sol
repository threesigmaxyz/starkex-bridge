//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { BridgeDiamond }  from "src/BridgeDiamond.sol";

import { DiamondCutFacet } from "src/facets/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/facets/DiamondLoupeFacet.sol";
import { AccessControlFacet } from "src/facets/AccessControlFacet.sol";

import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "src/interfaces/IDiamondLoupe.sol";

contract DeployBridgeModuleScript is Script {

    address public operator;
    address public lzEndpoint;

    //address public operator;

    function setUp() public {
        operator = vm.envAddress("SCALABLE_DEX_ADDRESS");
        lzEndpoint = vm.envAddress("LAYER_ZERO_ENDPOINT");
    }

    function run() external {
        // record calls and contract creations made by our script contract
        vm.startBroadcast();

        // bridge = new DiamondBridge();

        // bridge.initialize(operator, starkex_caller, LAYER_ZERO_ENDPOINT);

        // stop recording calls
        vm.stopBroadcast();
    }
}
