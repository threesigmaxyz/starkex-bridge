//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";

import { BridgeDiamond } from "src/BridgeDiamond.sol";

import { Constants } from "src/constants/Constants.sol";

import { LibDeployBridge } from "common/LibDeployBridge.sol";

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";

import { LzReceptor } from "src/interoperability/LzReceptor.sol";

import { TimelockController } from "@openzeppelin/governance/TimelockController.sol";

import { DataIO } from "script/data/DataIO.sol";

contract DeployBridgeReceptorTimelockModuleScript is Script, DataIO {
    address private _owner;
    address private _operator;
    address private _tokenAdmin;
    address private _bridge;
    address private _lzEndpoint;
    address private _timelockController;

    LzReceptor private _receptor;

    uint256 private TIMELOCK_MINIMUM_DELAY;

    function setUp() public {
        _owner = vm.rememberKey(vm.envUint("OWNER_PRIVATE_KEY"));
        _operator = vm.envAddress("STARKEX_OPERATOR");
        _tokenAdmin = vm.envAddress("TOKEN_ADMIN");
        _lzEndpoint = vm.envAddress("LAYER_ZERO_ENDPOINT");
        TIMELOCK_MINIMUM_DELAY = vm.envUint("TIMELOCK_MINIMUM_DELAY");
    }

    function run() external {
        // Record calls and contract creations made by our script contract.
        vm.startBroadcast(_owner);

        // Deploy bridge.
        _bridge = LibDeployBridge.deployBridge(_owner);
        _writeData("bridge", vm.toString(abi.encodePacked((_bridge))));

        // Deploy recepetor.
        _receptor = new LzReceptor(_lzEndpoint, _bridge);
        _writeData("receptor", vm.toString(address(_receptor)));

        // Deploy timelockController contract with zero minimum delay.
        _timelockController = _deployTimelockController_WithZeroMinimumDelay(_owner);
        _writeData("timelockController", vm.toString(_timelockController));

        // Set pending roles.
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.STARKEX_OPERATOR_ROLE, _operator);
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.TOKEN_ADMIN_ROLE, _tokenAdmin);
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE, address(_receptor));
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.OWNER_ROLE, _timelockController);

        // Accept interoperability role.
        _receptor.acceptBridgeRole();

        // Make the timelockController accept the bridge owner role.
        _timelockControllerAcceptBridgeRole();

        // Set the minimum delay of the timelockController contract.
        _setTimelockControllerMinimumDelay(TIMELOCK_MINIMUM_DELAY);

        // Stop recording calls.
        vm.stopBroadcast();
    }

    function _deployTimelockController_WithZeroMinimumDelay(address owner_) private returns (address) {
        // Only owner can propose and cancel actions.
        address[] memory proposers_ = new address[](1);
        proposers_[0] = owner_;

        // For anyone to be able to execute actions, address(0) should be an executor. See TimelockController.sol.
        address[] memory executors_ = new address[](1);
        executors_[0] = address(0);

        // Minimum delay is 0 to accept the bridge owner role instantly.
        uint256 minimumDelay_ = 0;

        // Admin role is 0, should not be needed.
        address admin_ = address(0);

        return address(new TimelockController(minimumDelay_, proposers_, executors_, admin_));
    }

    function _timelockControllerAcceptBridgeRole() internal {
        address target_ = _bridge;
        uint256 value_ = 0;
        bytes memory calldata_ =
            abi.encodeWithSelector(IAccessControlFacet.acceptRole.selector, LibAccessControl.OWNER_ROLE);
        bytes32 predecessor = bytes32(0);
        bytes32 salt = bytes32(0);
        uint256 delay_ = 0;

        // Propose action.
        TimelockController(payable(_timelockController)).schedule(target_, value_, calldata_, predecessor, salt, delay_);

        // Execute action.
        TimelockController(payable(_timelockController)).execute(target_, value_, calldata_, predecessor, salt);
    }

    function _setTimelockControllerMinimumDelay(uint256 minimumDelay_) internal {
        address target_ = _timelockController;
        uint256 value_ = 0;
        bytes memory calldata_ = abi.encodeWithSelector(TimelockController.updateDelay.selector, minimumDelay_);
        bytes32 predecessor = bytes32(0);
        bytes32 salt = bytes32(0);
        uint256 delay_ = 0;

        // Propose action.
        TimelockController(payable(_timelockController)).schedule(target_, value_, calldata_, predecessor, salt, delay_);

        // Execute action.
        TimelockController(payable(_timelockController)).execute(target_, value_, calldata_, predecessor, salt);
    }
}
