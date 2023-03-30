//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { MultiBridgeTransmitter } from "src/interoperability/MultiBridgeTransmitter.sol";

import { LzTransmitter } from "src/interoperability/LzTransmitter.sol";

import { DataIO } from "script/data/DataIO.sol";

contract DeployTransmitterModuleScript is Script, DataIO {
    address public _starkEx;
    address public _lzEndpoint;
    address public _lzReceptor;
    address public _owner;

    LzTransmitter public _lzTransmitter;
    MultiBridgeTransmitter public _multiBridgeTransmitter;

    function setUp() public {
        _owner = vm.rememberKey(vm.envUint("OWNER_PRIVATE_KEY"));
        _lzEndpoint = vm.envAddress("LAYER_ZERO_ENDPOINT");
        _lzReceptor = vm.parseAddress(_readData("lzReceptor"));
        _starkEx = vm.envAddress("STARKEX");
    }

    function run() external {
        // Record calls and contract creations made by our script contract.
        vm.startBroadcast(_owner);

        // Deploy lz transmitter.
        _lzTransmitter = new LzTransmitter(_lzEndpoint);
        _writeData("lzTransmitter", vm.toString(address(_lzTransmitter)));

        _lzTransmitter.setTrustedRemote(
            uint16(vm.envUint("SIDE_CHAIN_ID")), abi.encodePacked(address(_lzReceptor), address(_lzTransmitter))
        );

        // Deploy Multi-Bridge transmitter.
        _multiBridgeTransmitter = new MultiBridgeTransmitter(_starkEx);
        _writeData("multiBridgeTransmitter", vm.toString(address(_multiBridgeTransmitter)));

        _multiBridgeTransmitter.addBridge(address(_lzTransmitter));

        // Stop recording calls.
        vm.stopBroadcast();
    }
}
