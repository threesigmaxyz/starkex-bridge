//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { LzReceptor } from "src/interoperability/LzReceptor.sol";

contract ConfigureReceptorModuleScript is Script {
    address public _transmitter;
    address public _owner;
    LzReceptor public _receptor;

    function setUp() public {
        _receptor = LzReceptor(vm.parseAddress(_readFromFile("transmitter")));
        _transmitter = vm.parseAddress(_readFromFile("transmitter"));
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

    function _readFromFile(string memory name_) internal view returns (string memory) {
        bytes memory root_ = bytes(vm.projectRoot());
        string memory dirPath_ = string(bytes.concat(root_, "/script/data/"));
        string memory path_ = string(bytes.concat(bytes(dirPath_), bytes(name_)));
        return vm.readFile(path_);
    }
}
