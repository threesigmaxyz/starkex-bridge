//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { LzTransmitter } from "src/interoperability/LzTransmitter.sol";

import { CelerTransmitter } from "src/interoperability/CelerTransmitter.sol";

import { DataIO } from "script/data/DataIO.sol";

contract DeployTransmitterModuleScript is Script, DataIO {
    address public _starkEx;
    address public _lzEndpoint;
    address public _lzReceptor;
    address public _celerMessageBus;
    address public _celerReceptor;
    address public _owner;

    LzTransmitter public _lzTransmitter;
    CelerTransmitter public _celerTransmitter;

    function setUp() public {
        _owner = vm.rememberKey(vm.envUint("OWNER_PRIVATE_KEY"));
        _lzEndpoint = vm.envAddress("LAYER_ZERO_ENDPOINT");
        _celerMessageBus = vm.envAddress("CELER_MESSAGE_BUS");
        _lzReceptor = vm.parseAddress(_readData("lzReceptor"));
        _celerReceptor = vm.parseAddress(_readData("celerReceptor"));
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

        // Deploy celer transmitter.
        _celerTransmitter = new CelerTransmitter(_celerMessageBus, _starkEx);
        _writeData("celerTransmitter", vm.toString(address(_celerTransmitter)));

        _celerTransmitter.setTrustedRemote(
            uint16(vm.envUint("SIDE_CHAIN_ID")), abi.encodePacked(address(_celerReceptor))
        );

        // Stop recording calls.
        vm.stopBroadcast();
    }
}
