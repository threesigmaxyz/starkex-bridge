//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { LzTransmitter } from "src/interoperability/LzTransmitter.sol";

import { WormholeTransmitter } from "src/interoperability/WormholeTransmitter.sol";

import { DataIO } from "script/data/DataIO.sol";

contract DeployTransmitterModuleScript is Script, DataIO {
    address public _starkEx;
    address public _lzEndpoint;
    address public _lzReceptor;
    address public _wormhole;
    address public _wormholeRelayer;
    address public _wormholeReceptor;
    address public _owner;

    LzTransmitter public _lzTransmitter;
    WormholeTransmitter public _wormholeTransmitter;

    function setUp() public {
        _owner = vm.rememberKey(vm.envUint("OWNER_PRIVATE_KEY"));
        _lzEndpoint = vm.envAddress("LAYER_ZERO_ENDPOINT");
        _wormhole = vm.envAddress("WORMHOLE");
        _wormholeRelayer = vm.envAddress("WORMHOLE_RELAYER");
        _lzReceptor = vm.parseAddress(_readData("lzReceptor"));
        _wormholeReceptor = vm.parseAddress(_readData("wormholeReceptor"));
        _starkEx = vm.envAddress("STARKEX");
    }

    function run() external {
        // Record calls and contract creations made by our script contract.
        vm.startBroadcast(_owner);

        // Deploy lz transmitter.
        _lzTransmitter = new LzTransmitter(_lzEndpoint, _starkEx);
        _writeData("lzTransmitter", vm.toString(address(_lzTransmitter)));

        _lzTransmitter.setTrustedRemote(
            uint16(vm.envUint("SIDE_CHAIN_ID")), abi.encodePacked(address(_lzReceptor), address(_lzTransmitter))
        );

        // Deploy wormhole transmitter.
        _wormholeTransmitter = new WormholeTransmitter(_wormhole, _wormholeRelayer, _starkEx);
        _writeData("wormholeTransmitter", vm.toString(address(_wormholeTransmitter)));

        _wormholeTransmitter.setTrustedRemote(
            uint16(vm.envUint("SIDE_CHAIN_ID")), abi.encodePacked(address(_wormholeReceptor))
        );

        // Stop recording calls.
        vm.stopBroadcast();
    }
}
