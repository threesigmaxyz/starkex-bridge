//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";
import { IERC165 } from "@openzeppelin/interfaces/IERC165.sol";

import { Constants } from "src/constants/Constants.sol";

import { MockERC20 } from "test/mocks/MockERC20.sol";

import { BridgeDiamond } from "src/BridgeDiamond.sol";

import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { ITokenRegisterFacet } from "src/interfaces/facets/ITokenRegisterFacet.sol";

import { LibDeployBridge } from "common/LibDeployBridge.sol";

contract BaseFixture is Test {
    uint256 internal constant USER_TOKENS = type(uint256).max;
    uint256 internal constant USER_NATIVE = type(uint256).max;

    address _bridge;
    MockERC20 _token;

    function setUp() public virtual {
        _setLabels();

        vm.startPrank(_owner());
        _bridge = LibDeployBridge.deployBridge(_owner());
        _setPendingRoles(_bridge, _mockInteropContract());
        vm.stopPrank();

        _acceptPendingRoles(_bridge);

        // Has to be separate from the above because the interop role might be a contract.
        vm.prank(_mockInteropContract());
        IAccessControlFacet(_bridge).acceptRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);

        // Deploy _token
        vm.prank(_tokenDeployer());
        _token = (new MockERC20){salt: "USDC"}("USD Coin", "USDC", 6); // 0xa33e385d3ab4a55cc949115bb5cb57fb16143d4b

        _token.mint(_user(), USER_TOKENS);

        // Deal native to user
        vm.deal(_user(), USER_NATIVE);

        // Register _token in _bridge
        vm.prank(_tokenAdmin());
        ITokenRegisterFacet(_bridge).setTokenRegister(address(_token), true);
    }

    function _setPendingRoles(address bridge_, address interoperabilityContract_) internal {
        IAccessControlFacet(bridge_).setPendingRole(LibAccessControl.STARKEX_OPERATOR_ROLE, _operator());
        IAccessControlFacet(bridge_).setPendingRole(
            LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE, interoperabilityContract_
        );
        IAccessControlFacet(bridge_).setPendingRole(LibAccessControl.TOKEN_ADMIN_ROLE, _tokenAdmin());
    }

    function _acceptPendingRoles(address bridge_) internal {
        vm.prank(_operator());
        IAccessControlFacet(bridge_).acceptRole(LibAccessControl.STARKEX_OPERATOR_ROLE);
        vm.prank(_tokenAdmin());
        IAccessControlFacet(bridge_).acceptRole(LibAccessControl.TOKEN_ADMIN_ROLE);
    }

    function _setLabels() internal {
        vm.label(_owner(), "owner");
        vm.label(_operator(), "operator");
        vm.label(_mockInteropContract(), "mockInteropContract");
        vm.label(_tokenAdmin(), "tokenAdmin");
        vm.label(_tokenDeployer(), "tokenDeployer");
        vm.label(_user(), "user");
        vm.label(_recipient(), "recipient");
        vm.label(_intruder(), "intruder");
    }

    function _getNativeOrERC20Balance(address token_, address user_) internal view returns (uint256) {
        return token_ == Constants.NATIVE ? user_.balance : MockERC20(token_).balanceOf(user_);
    }

    function _owner() internal pure returns (address) {
        return vm.addr(1337);
    }

    function _operator() internal pure returns (address) {
        return vm.addr(420);
    }

    function _mockInteropContract() internal pure returns (address) {
        return vm.addr(1338);
    }

    function _tokenAdmin() internal pure returns (address) {
        return vm.addr(888);
    }

    function _tokenDeployer() internal pure returns (address) {
        return vm.addr(666);
    }

    function _user() internal pure returns (address) {
        return vm.addr(789);
    }

    function _recipient() internal pure returns (address) {
        return vm.addr(777);
    }

    function _intruder() internal pure returns (address) {
        return vm.addr(999);
    }
}
