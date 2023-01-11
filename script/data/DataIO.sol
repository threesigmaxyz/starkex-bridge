//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

abstract contract DataIO is Script {
    function _writeData(string memory name, string memory _data) internal {
        bytes memory root_ = bytes(vm.projectRoot());
        string memory path_ = string(bytes.concat(root_, "/script/data/", bytes(name)));
        vm.writeFile(path_, _data);
    }

    function _readData(string memory name_) internal view returns (string memory) {
        bytes memory root_ = bytes(vm.projectRoot());
        string memory dirPath_ = string(bytes.concat(root_, "/script/data/"));
        string memory path_ = string(bytes.concat(bytes(dirPath_), bytes(name_)));
        return vm.readFile(path_);
    }
}
