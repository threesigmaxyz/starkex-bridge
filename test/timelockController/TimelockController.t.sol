// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";

import { TimelockController } from "@openzeppelin/governance/TimelockController.sol";

contract TimelockControllerTest is Test {
    address _owner;

    function setUp() public virtual {
        _owner = vm.addr(1);
        vm.label(_owner, "owner");
        vm.deal(_owner, 10 ether);
    }

    /// @dev Test that the TimelockController can be deployed with a minimum delay of 0.
    function test_ZeroMinimumDelay() public {
        vm.startPrank(_owner);

        // Only owner can propose and cancel actions.
        address[] memory proposers_ = new address[](1);
        proposers_[0] = _owner;

        // Anyone can execute actions.
        address[] memory executors_ = new address[](1);
        executors_[0] = address(0);

        uint256 minimumDelay_ = 0;
        address admin_ = address(0);

        TimelockController timelockController_ = new TimelockController(minimumDelay_, proposers_, executors_, admin_);

        // Need to warp because the TimelockController sets the _DONE_TIMESTAMP as block.timestamp, which is 1.
        vm.warp(2);

        uint256 newMinimumDelay_ = 10;

        address target_ = address(timelockController_);
        uint256 value_ = 0;
        bytes memory calldata_ = abi.encodeWithSelector(timelockController_.updateDelay.selector, newMinimumDelay_);
        bytes32 predecessor = bytes32(0);
        bytes32 salt = bytes32(0);

        // Propose action.
        timelockController_.schedule(target_, value_, calldata_, predecessor, salt, minimumDelay_);

        // Execute action.
        timelockController_.execute(target_, value_, calldata_, predecessor, salt);

        assertEq(timelockController_.getMinDelay(), newMinimumDelay_);

        vm.stopPrank();
    }
}
