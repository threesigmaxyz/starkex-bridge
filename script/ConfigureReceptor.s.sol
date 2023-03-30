//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { MultiBridgeReceptor } from "src/interoperability/MultiBridgeReceptor.sol";

import { LzReceptor } from "src/interoperability/LzReceptor.sol";

import { DataIO } from "script/data/DataIO.sol";

contract ConfigureReceptorModuleScript is Script, DataIO {
    address public _lzTransmitter;
    address public _multiBridgeTransmitter;
    address public _owner;
    LzReceptor public _lzReceptor;
    MultiBridgeReceptor public _multiBridgeReceptor;
    uint16 public _mainChainId;

    function setUp() public {
        _lzReceptor = LzReceptor(vm.parseAddress(_readData("lzReceptor")));
        _lzTransmitter = vm.parseAddress(_readData("lzTransmitter"));
        _multiBridgeReceptor = MultiBridgeReceptor(vm.parseAddress(_readData("multiBridgeReceptor")));
        _multiBridgeTransmitter = vm.parseAddress(_readData("multiBridgeTransmitter"));
        _owner = vm.rememberKey(vm.envUint("OWNER_PRIVATE_KEY"));
        _mainChainId = uint16(vm.envUint("MAIN_CHAIN_ID"));
    }

    function run() external {
        // Record calls and contract creations made by our script contract.
        vm.startBroadcast(_owner);

        // For lz.
        bytes memory path_ = abi.encodePacked(address(_lzTransmitter), address(_lzReceptor));
        // Check if the receptor is already configured.
        require(!_lzReceptor.isTrustedRemote(_mainChainId, path_), "Lz receptor is already configured.");
        // Set receptor trusted remote.
        _lzReceptor.setTrustedRemote(_mainChainId, path_);

        // For multi-Bridge.
        // Check if the receptor is already configured.
        require(_multiBridgeReceptor.getTotalWeight() == 0, "Multi-Bridge receptor is already configured.");
        // Set receptor bridges and threshold.
        _multiBridgeReceptor.updateBridgeWeight(address(_lzReceptor), 10);
        _multiBridgeReceptor.updateThreshold(50);

        // Stop recording calls.
        vm.stopBroadcast();
    }
}
