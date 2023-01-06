//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { LzReceptor } from "src/interoperability/LzReceptor.sol";

import { DataIO } from "script/data/DataIO.sol";

contract ConfigureReceptorModuleScript is Script, DataIO {
    address public _transmitter;
    address public _owner;
    LzReceptor public _receptor;
    uint16 public _mainChainId;

    function setUp() public {
        _receptor = LzReceptor(vm.parseAddress(_readData("receptor")));
        _transmitter = vm.parseAddress(_readData("transmitter"));
        _owner = vm.rememberKey(vm.envUint("OWNER_PRIVATE_KEY"));
        _mainChainId = uint16(vm.envUint("MAIN_CHAIN_ID"));
    }

    function run() external {
        // Record calls and contract creations made by our script contract.
        vm.startBroadcast(_owner);

        bytes memory path_ = abi.encodePacked(address(_transmitter), address(_receptor));

        // Check if the receptor is already configured.
        require(!_receptor.isTrustedRemote(_mainChainId, path_), "Receptor is already configured.");

        // Set receptor trusted remote.
        _receptor.setTrustedRemote(_mainChainId, path_);

        // Stop recording calls.
        vm.stopBroadcast();
    }
}