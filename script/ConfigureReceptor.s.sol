//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { LzReceptor } from "src/interoperability/LzReceptor.sol";

import { CelerReceptor } from "src/interoperability/CelerReceptor.sol";

import { DataIO } from "script/data/DataIO.sol";

contract ConfigureReceptorModuleScript is Script, DataIO {
    address public _lzTransmitter;
    address public _celerTransmitter;
    address public _owner;
    LzReceptor public _lzReceptor;
    CelerReceptor public _celerReceptor;
    uint16 public _mainChainId;

    function setUp() public {
        _lzReceptor = LzReceptor(vm.parseAddress(_readData("lzReceptor")));
        _celerReceptor = CelerReceptor(vm.parseAddress(_readData("celerReceptor")));
        _lzTransmitter = vm.parseAddress(_readData("lzTransmitter"));
        _celerTransmitter = vm.parseAddress(_readData("celerTransmitter"));
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

        // For celer.
        bytes memory celerPath_ = abi.encodePacked(address(_celerTransmitter));
        // Check if the receptor is already configured.
        require(!_celerReceptor.isTrustedRemote(_mainChainId, celerPath_), "Celer receptor is already configured.");
        // Set receptor trusted remote.
        _celerReceptor.setTrustedRemote(_mainChainId, celerPath_);

        // Stop recording calls.
        vm.stopBroadcast();
    }
}
