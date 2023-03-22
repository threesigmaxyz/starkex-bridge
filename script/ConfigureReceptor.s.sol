//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { LzReceptor } from "src/interoperability/LzReceptor.sol";

import { WormholeReceptor } from "src/interoperability/WormholeReceptor.sol";

import { DataIO } from "script/data/DataIO.sol";

contract ConfigureReceptorModuleScript is Script, DataIO {
    address public _lzTransmitter;
    address public _wormholeTransmitter;
    address public _owner;
    LzReceptor public _lzReceptor;
    WormholeReceptor public _wormholeReceptor;
    uint16 public _mainChainId;

    function setUp() public {
        _lzReceptor = LzReceptor(vm.parseAddress(_readData("lzReceptor")));
        _wormholeReceptor = WormholeReceptor(vm.parseAddress(_readData("wormholeReceptor")));
        _lzTransmitter = vm.parseAddress(_readData("lzTransmitter"));
        _wormholeTransmitter = vm.parseAddress(_readData("wormholeTransmitter"));
        _owner = vm.rememberKey(vm.envUint("OWNER_PRIVATE_KEY"));
        _mainChainId = uint16(vm.envUint("MAIN_CHAIN_ID"));
    }

    function run() external {
        // Record calls and contract creations made by our script contract.
        vm.startBroadcast(_owner);

        // For lz.
        bytes memory lzPath_ = abi.encodePacked(address(_lzTransmitter), address(_lzReceptor));
        // Check if the receptor is already configured.
        require(!_lzReceptor.isTrustedRemote(_mainChainId, lzPath_), "Lz receptor is already configured.");
        // Set receptor trusted remote.
        _lzReceptor.setTrustedRemote(_mainChainId, lzPath_);

        // For wormhole.
        bytes memory wormholePath_ = abi.encodePacked(address(_wormholeTransmitter));
        // Check if the receptor is already configured.
        require(
            !_wormholeReceptor.isTrustedRemote(_mainChainId, wormholePath_), "Wormhole receptor is already configured."
        );
        // Set receptor trusted remote.
        _wormholeReceptor.setTrustedRemote(_mainChainId, wormholePath_);

        // Stop recording calls.
        vm.stopBroadcast();
    }
}
