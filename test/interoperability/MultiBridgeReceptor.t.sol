// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";

import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";

import { MultiBridgeReceptor } from "src/interoperability/MultiBridgeReceptor.sol";
import { IMultiBridgeReceptor } from "src/interfaces/interoperability/IMultiBridgeReceptor.sol";

contract MultiBridgeReceptorTest is Test {
    uint16 private constant MOCK_CHAIN_ID = 1337;

    MultiBridgeReceptor private _receptor;
    address private _bridge = vm.addr(1);
    address private _transmitter = vm.addr(2);
    address private _bridge1 = vm.addr(3);
    address private _bridge2 = vm.addr(4);
    address private _bridge3 = vm.addr(5);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event LogSetBridge(address indexed bridge);
    event LogOrderRootUpdate(uint256 indexed orderRoot);
    event LogBridgeRoleAccepted();
    event LogRootSigleMsgReceived(uint16 indexed srcChainId, address indexed bridgeReceiver, uint256 indexed orderRoot);
    event LogRootMsgExecuted(uint256 indexed orderRoot, uint256 indexed sequenceNumber);
    event LogThresholdUpdated(uint64 indexed threshold);
    event LogUpdatedBridgeWeight(address indexed bridge, uint32 indexed newWeight);
    event LogOutdatedRootReceived(uint16 indexed srcChainId, uint256 indexed orderRoot, uint256 indexed sequenceNumber);

    function setUp() public {
        vm.label(_owner(), "owner");
        vm.label(_intruder(), "intruder");
        vm.label(_bridge, "bridge");
        vm.label(_transmitter, "transmitter");
        vm.label(_bridge1, "bridge1");
        vm.label(_bridge2, "bridge2");
        vm.label(_bridge3, "bridge3");

        vm.etch(_bridge1, "Add Code or it reverts");
        vm.etch(_bridge2, "Add Code or it reverts");
        vm.etch(_bridge3, "Add Code or it reverts");

        _receptor = MultiBridgeReceptor(_constructor(_owner(), _bridge));

        address[] memory bridges_ = new address[](3);
        bridges_[0] = _bridge1;
        bridges_[1] = _bridge2;
        bridges_[2] = _bridge3;

        uint32[] memory weights_ = new uint32[](3);
        weights_[0] = 100;
        weights_[1] = 100;
        weights_[2] = 100;

        _setBridgeReceptors(_owner(), bridges_, weights_);

        _setThreshold(_owner(), 50);
    }

    //==============================================================================//
    //=== constructor Tests                                                      ===//
    //==============================================================================//

    function test_constructor_ok(address bridge_) public {
        vm.assume(bridge_ > address(0));

        // Arrange
        vm.label(bridge_, "bridge");

        // Act + Assert
        _constructor(_owner(), bridge_);
    }

    function test_constructor_ZeroBridgeAddressError() public {
        // Arrange
        address bridge_ = address(0);
        vm.expectRevert(abi.encodeWithSelector(IMultiBridgeReceptor.ZeroBridgeAddressError.selector));

        // Act + Assert
        new MultiBridgeReceptor(bridge_);
    }

    //==============================================================================//
    //=== acceptBridgeRole Tests                                                 ===//
    //==============================================================================//

    function test_acceptBridgeRole_ok() public {
        // Arrange
        vm.mockCall(
            _bridge,
            abi.encodeWithSelector(IAccessControlFacet.acceptRole.selector),
            abi.encode(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE)
        );

        // Act + Assert
        _acceptBridgeRole(address(_receptor));
    }

    //==============================================================================//
    //=== setOrderRoot Tests                                                     ===//
    //==============================================================================//

    function test_setOrderRoot_ok() public {
        // Arrange
        uint256 orderRoot_ = 0;
        vm.mockCall(_bridge, abi.encodeWithSelector(IStateFacet.setOrderRoot.selector), abi.encode(orderRoot_));

        // Act + Assert
        _setOrderRoot(_owner(), address(_receptor), orderRoot_);
    }

    function test_setOrderRoot_onlyOwner() public {
        // Arrange
        vm.expectRevert("Ownable: caller is not the owner");

        // Act + Assert
        vm.prank(_intruder());
        _receptor.setOrderRoot();
    }

    //==============================================================================//
    //=== updateThreshold Tests                                                  ===//
    //==============================================================================//

    function test_updateThreshold_ok(uint64 threshold_) public {
        // Arrange
        vm.assume(threshold_ <= 100);

        // Act + Assert
        _setThreshold(_owner(), threshold_);
    }

    function test_updateThreshold_InvalidThresholdError(uint64 threshold_) public {
        // Arrange
        vm.assume(threshold_ > 100);
        // And
        vm.expectRevert(abi.encodeWithSelector(IMultiBridgeReceptor.InvalidThresholdError.selector));

        // Act + Assert
        vm.prank(_owner());
        _receptor.updateThreshold(threshold_);
    }

    function test_updateThreshold_onlyOwner() public {
        // Arrange
        vm.expectRevert("Ownable: caller is not the owner");

        // Act + Assert
        vm.prank(_intruder());
        _receptor.updateThreshold(50);
    }

    //==============================================================================//
    //=== updateBridgeWeight Tests                                               ===//
    //==============================================================================//

    function test_updateBridgeWeight_ok(address bridge_, uint32 weight_) public {
        // Arrange
        vm.expectEmit(true, true, false, true, address(_receptor));
        emit LogUpdatedBridgeWeight(bridge_, weight_);

        // Act + Assert
        vm.prank(_owner());
        _receptor.updateBridgeWeight(bridge_, weight_);
        assertEq(_receptor.getBridgesWeight(bridge_), weight_);
    }

    function test_updateBridgeWeight_onlyOwner() public {
        // Arrange
        vm.expectRevert("Ownable: caller is not the owner");

        // Act + Assert
        vm.prank(_intruder());
        _receptor.updateBridgeWeight(_bridge1, 50);
    }

    //==============================================================================//
    //=== receiveRoot Tests                                                      ===//
    //==============================================================================//

    function test_receiveRoot_ok(uint256 orderRoot_, uint256 sequenceNumber_, uint16 srcChainId_) public {
        // Arrange
        vm.assume(sequenceNumber_ > 0);

        // Act + Assert
        _receiveRoot(orderRoot_, sequenceNumber_, srcChainId_);
    }

    function test_receiveRoot_LogOutdatedRootReceived() public {
        // Arrange
        uint256 orderRootB_ = 0;
        uint256 orderRootA_ = 1;
        uint256 sequenceNumberB_ = 1;
        uint256 sequenceNumberA_ = 3;
        // And
        _receiveRoot(orderRootA_, sequenceNumberA_, MOCK_CHAIN_ID);
        // And
        bytes memory payload_ = abi.encode(abi.encode(orderRootB_), sequenceNumberB_);
        // And
        vm.expectEmit(true, true, true, true, address(_receptor));
        emit LogOutdatedRootReceived(MOCK_CHAIN_ID, orderRootB_, sequenceNumberB_);

        // Act
        vm.prank(_bridge1);
        _receptor.receiveRoot(payload_, MOCK_CHAIN_ID);
    }

    function test_receiveRoot_MessageAlreadyExecuted() public {
        // Arrange
        uint256 orderRoot_ = 0;
        uint256 sequenceNumber_ = 1;
        // And
        _receiveRoot(orderRoot_, sequenceNumber_, MOCK_CHAIN_ID);
        // And
        bytes memory payload_ = abi.encode(abi.encode(orderRoot_), sequenceNumber_);
        // And
        vm.expectEmit(true, true, true, true, address(_receptor));
        emit LogOutdatedRootReceived(MOCK_CHAIN_ID, orderRoot_, sequenceNumber_);

        // Act
        vm.prank(_bridge3);
        _receptor.receiveRoot(payload_, MOCK_CHAIN_ID);
    }

    function test_receiveRoot_NotAllowedBridgeError() public {
        // Arrange
        uint256 orderRoot_ = 0;
        uint256 sequenceNumber_ = 1;
        // And
        bytes memory payload_ = abi.encode(abi.encode(orderRoot_), sequenceNumber_);
        // And
        vm.expectRevert(abi.encodeWithSelector(IMultiBridgeReceptor.NotAllowedBridgeError.selector));

        // Act
        vm.prank(_intruder());
        _receptor.receiveRoot(payload_, MOCK_CHAIN_ID);
    }

    function test_receiveRoot_AlreadyReceivedFromBridgeError() public {
        // Arrange
        uint256 orderRoot_ = 0;
        uint256 sequenceNumber_ = 1;
        // And
        _receiveRoot(orderRoot_, sequenceNumber_, MOCK_CHAIN_ID);
        // And
        bytes memory payload_ = abi.encode(abi.encode(orderRoot_), sequenceNumber_);
        // And
        vm.expectRevert(abi.encodeWithSelector(IMultiBridgeReceptor.AlreadyReceivedFromBridgeError.selector));

        // Act
        vm.prank(_bridge1);
        _receptor.receiveRoot(payload_, MOCK_CHAIN_ID);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _constructor(address owner_, address bridge_) internal returns (address receptor_) {
        // Arrange
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(address(0), owner_);
        vm.expectEmit(true, false, false, true);
        emit LogSetBridge(bridge_);

        // Act
        vm.prank(owner_);
        receptor_ = address(new MultiBridgeReceptor(bridge_));
    }

    function _setBridgeReceptors(address owner_, address[] memory bridges_, uint32[] memory weights_) internal {
        // Arrange
        for (uint256 i = 0; i < bridges_.length; i++) {
            vm.expectEmit(true, true, false, true, address(_receptor));
            emit LogUpdatedBridgeWeight(bridges_[i], weights_[i]);
        }

        // Act + Assert
        vm.startPrank(owner_);
        for (uint256 f = 0; f < bridges_.length; f++) {
            _receptor.updateBridgeWeight(bridges_[f], weights_[f]);
        }
        vm.stopPrank();
        for (uint256 z = 0; z < bridges_.length; z++) {
            assertEq(_receptor.getBridgesWeight(bridges_[z]), weights_[z]);
        }
    }

    function _setThreshold(address owner_, uint64 threshold_) internal {
        // Arrange
        vm.expectEmit(true, true, false, true, address(_receptor));
        emit LogThresholdUpdated(threshold_);

        // Act + Assert
        vm.prank(owner_);
        _receptor.updateThreshold(threshold_);
        assertEq(_receptor.getThreshold(), threshold_);
    }

    function _acceptBridgeRole(address receptor_) internal {
        // Arrange
        vm.expectEmit(false, false, false, true, receptor_);
        emit LogBridgeRoleAccepted();

        // Act + Assert
        IMultiBridgeReceptor(receptor_).acceptBridgeRole();
    }

    function _setOrderRoot(address owner_, address receptor_, uint256 orderRoot_) internal {
        // Arrange
        vm.expectEmit(true, false, false, true, receptor_);
        emit LogOrderRootUpdate(orderRoot_);

        vm.prank(owner_);
        IMultiBridgeReceptor(receptor_).setOrderRoot();
    }

    function _receiveRoot(uint256 orderRoot_, uint256 sequenceNumber_, uint16 srcChainId_) internal {
        // Arrange
        bytes memory payload_ = abi.encode(abi.encode(orderRoot_), sequenceNumber_);
        // And
        vm.expectEmit(true, true, true, true, address(_receptor));
        emit LogRootSigleMsgReceived(srcChainId_, _bridge1, orderRoot_);

        // Act + Arrange
        vm.prank(_bridge1);
        _receptor.receiveRoot(payload_, srcChainId_);
        assertEq(_receptor.getMsgWeight(_receptor.getMsgId(orderRoot_, srcChainId_)), 100);

        // Arrange
        vm.expectEmit(true, true, true, true, address(_receptor));
        emit LogRootSigleMsgReceived(srcChainId_, _bridge2, orderRoot_);
        // And
        vm.expectEmit(true, true, false, true, address(_receptor));
        emit LogRootMsgExecuted(orderRoot_, sequenceNumber_);

        // Act + Arrange
        vm.prank(_bridge2);
        _receptor.receiveRoot(payload_, srcChainId_);
        assertEq(_receptor.getMsgWeight(_receptor.getMsgId(orderRoot_, srcChainId_)), 200);
    }

    function _owner() internal pure returns (address) {
        return vm.addr(1337);
    }

    function _intruder() internal pure returns (address) {
        return vm.addr(999);
    }
}
