//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { LzTransmitter } from "src/interoperability/LzTransmitter.sol";

import { DataIO } from "script/data/DataIO.sol";

contract DeployTransmitterModuleScript is Script, DataIO {
    address public _starkEx;
    address public _lzEndpoint;
    address public _receptor;
    address public _owner;

    LzTransmitter public _transmitter;

    function setUp() public {
        _owner = vm.rememberKey(vm.envUint("OWNER_PRIVATE_KEY"));
        _lzEndpoint = vm.envAddress("LAYER_ZERO_ENDPOINT");
        _receptor = vm.parseAddress(_readData("receptor"));
        _starkEx = vm.envAddress("STARKEX");
    }

    function run() external {
        // Record calls and contract creations made by our script contract.
        vm.startBroadcast(_owner);

        // Deploy transmitter.
        _transmitter = new LzTransmitter(_lzEndpoint, _starkEx);
        _writeData("transmitter", vm.toString(address(_transmitter)));

        _transmitter.setTrustedRemote(
            uint16(vm.envUint("SIDE_CHAIN_ID")), abi.encodePacked(address(_receptor), address(_transmitter))
        );

        // Stop recording calls.
        vm.stopBroadcast();
    }
}
