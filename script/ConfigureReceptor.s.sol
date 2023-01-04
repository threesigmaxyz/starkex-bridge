//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { LzReceptor } from "src/interoperability/LzReceptor.sol";

import { DataIO } from "script/data/DataIO.sol";

contract ConfigureReceptorModuleScript is Script, DataIO {
    address public _transmitter;
    address public _owner;
    LzReceptor public _receptor;

    function setUp() public {
        _receptor = LzReceptor(vm.parseAddress(_readData("receptor")));
        _transmitter = vm.parseAddress(_readData("transmitter"));
        _owner = vm.rememberKey(vm.envUint("OWNER_PRIVATE_KEY"));
    }

    function run() external {
        // Record calls and contract creations made by our script contract.
        vm.startBroadcast(_owner);

        // Set receptor trusted remote.
        _receptor.setTrustedRemote(
            uint16(vm.envUint("MAIN_CHAIN_ID")), abi.encodePacked(address(_transmitter), address(_receptor))
        );

        // Stop recording calls.
        vm.stopBroadcast();
    }
}
