// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { IWormhole } from "src/dependencies/wormhole/interfaces/IWormhole.sol";
import { ICoreRelayer } from "src/dependencies/wormhole/interfaces/ICoreRelayer.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { WormholeReceptor } from "src/interoperability/WormholeReceptor.sol";
import { WormholeBase } from "src/interoperability/wormhole/WormholeBase.sol";
import { IWormholeReceptor } from "src/interfaces/interoperability/IWormholeReceptor.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { IWormholeBase } from "src/interfaces/interoperability/wormhole/IWormholeBase.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";

contract WormholeReceptorTest is Test {
    uint16 private constant MOCK_CHAIN_ID = 1337;

    WormholeReceptor private _receptor;
    address private _wormhole = vm.addr(1);
    address private _relayer = vm.addr(2);
    address private _bridge = vm.addr(3);
    address private _transmitter = vm.addr(4);

    event LogSetBridge(address indexed bridge);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event LogSetTrustedRemote(uint16 indexed remoteChainId, bytes indexed path);
    event LogBridgeRoleAccepted();
    event LogRootReceived(uint256 indexed orderRoot);
    event LogOutdatedRootReceived(uint256 indexed orderRoot, uint64 indexed nonce);
    event LogOrderRootUpdate(uint256 indexed orderRoot);
    event LogMessageFailed(
        uint16 indexed srcChainId, bytes indexed path, uint64 indexed nonce, bytes payload, bytes reason
    );

    function setUp() public {
        vm.label(_owner(), "owner");
        vm.label(_intruder(), "intruder");
        vm.label(_wormhole, "wormhole");
        vm.label(_relayer, "relayer");
        vm.label(_transmitter, "transmitter");

        vm.etch(_wormhole, "Add Code or it reverts");
        vm.etch(_relayer, "Add Code or it reverts");

        _receptor = WormholeReceptor(_constructor(_owner(), _wormhole, _relayer, _bridge));
        _setTrustedRemote(_owner(), _transmitter, address(_receptor));
    }

    //==============================================================================//
    //=== constructor Tests                                                      ===//
    //==============================================================================//

    function test_constructor_ok(address wormhole_, address relayer_, address starkEx_) public {
        vm.assume(wormhole_ > address(0));
        vm.assume(relayer_ > address(0));
        vm.assume(starkEx_ > address(0));

        // Arrange
        vm.label(wormhole_, "wormhole");
        vm.label(relayer_, "relayer");
        vm.label(starkEx_, "bridge");

        // Act + Assert
        _constructor(_owner(), wormhole_, relayer_, starkEx_);
    }

    function test_constructor_ZeroWormholeAddressError() public {
        // Arrange
        address wormhole = address(0);
        vm.expectRevert(abi.encodeWithSelector(IWormholeReceptor.ZeroWormholeAddressError.selector));

        // Act + Assert
        new WormholeReceptor(wormhole, _relayer, _bridge);
    }

    function test_constructor_ZeroRelayerAddressError() public {
        // Arrange
        address relayer = address(0);
        vm.expectRevert(abi.encodeWithSelector(IWormholeReceptor.ZeroRelayerAddressError.selector));

        // Act + Assert
        new WormholeReceptor(_wormhole, relayer, _bridge);
    }

    function test_constructor_ZeroBridgeAddressError() public {
        // Arrange
        address bridge = address(0);
        vm.expectRevert(abi.encodeWithSelector(IWormholeReceptor.ZeroBridgeAddressError.selector));

        // Act + Assert
        new WormholeReceptor(_wormhole, _relayer, bridge);
    }

    //==============================================================================//
    //=== setTrustedRemote Tests                                                 ===//
    //==============================================================================//

    function test_setTrustedRemote_ok() public {
        // Act + Assert
        _setTrustedRemote(_owner(), _transmitter, address(_receptor));
    }

    function test_setTrustedRemote_onlyOwner() public {
        // Arrange
        vm.expectRevert("Ownable: caller is not the owner");

        // Act + Assert
        vm.prank(_intruder());
        _receptor.setTrustedRemote(MOCK_CHAIN_ID, abi.encode(0));
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
    //=== receiveWormholeMessages Tests                                          ===//
    //==============================================================================//

    function test_receiveWormholeMessages_ok(uint256 orderRoot_, bytes32 hash_) public {
        // Arrange
        IWormhole.VM memory vmMessage;
        vmMessage.payload = abi.encode(orderRoot_, abi.encodePacked(address(_receptor)));
        vmMessage.hash = hash_;
        vmMessage.emitterChainId = MOCK_CHAIN_ID;
        vmMessage.emitterAddress = bytes32(abi.encodePacked(address(_receptor)));

        bytes[] memory whMessages_ = new bytes[](1);
        whMessages_[0] = abi.encode(1);

        vm.mockCall(
            _wormhole,
            0,
            abi.encodeWithSelector(IWormhole.parseAndVerifyVM.selector, whMessages_[0]),
            abi.encode(vmMessage, true, "")
        );

        // Act + Assert
        _wormholeReceive(address(_receptor), orderRoot_, whMessages_);
    }

    function test_receiveWormholeMessages_InvalidCallerError(uint256 orderRoot_, bytes32 hash_) public {
        // Arrange
        IWormhole.VM memory vmMessage;
        vmMessage.payload = abi.encode(orderRoot_, abi.encodePacked(address(_receptor)));
        vmMessage.hash = hash_;
        vmMessage.emitterChainId = MOCK_CHAIN_ID;
        vmMessage.emitterAddress = bytes32(abi.encodePacked(address(_receptor)));

        bytes[] memory whMessages_ = new bytes[](1);
        whMessages_[0] = abi.encode(1);

        vm.mockCall(
            _wormhole,
            0,
            abi.encodeWithSelector(IWormhole.parseAndVerifyVM.selector, whMessages_[0]),
            abi.encode(vmMessage, true, "")
        );

        vm.expectRevert(abi.encodeWithSelector(IWormholeReceptor.InvalidCallerError.selector));

        // Act + Assert
        vm.prank(_wormhole);
        WormholeReceptor(_receptor).receiveWormholeMessages(whMessages_, whMessages_);
    }

    function test_receiveWormholeMessages_VerificationFailError(uint256 orderRoot_, bytes32 hash_) public {
        // Arrange
        IWormhole.VM memory vmMessage;
        vmMessage.payload = abi.encode(orderRoot_, abi.encodePacked(address(_receptor)));
        vmMessage.hash = hash_;
        vmMessage.emitterChainId = MOCK_CHAIN_ID;
        vmMessage.emitterAddress = bytes32(abi.encodePacked(address(_receptor)));

        bytes[] memory whMessages_ = new bytes[](1);
        whMessages_[0] = abi.encode(1);

        vm.mockCall(
            _wormhole,
            0,
            abi.encodeWithSelector(IWormhole.parseAndVerifyVM.selector, whMessages_[0]),
            abi.encode(vmMessage, false, "")
        );

        vm.expectRevert(abi.encodeWithSelector(IWormholeReceptor.VerificationFailError.selector, ""));

        // Act + Assert
        vm.prank(_relayer);
        WormholeReceptor(_receptor).receiveWormholeMessages(whMessages_, whMessages_);
    }

    function test_receiveWormholeMessages_InvalidEmitterError(uint256 orderRoot_, bytes32 hash_) public {
        // Arrange
        IWormhole.VM memory vmMessage;
        vmMessage.payload = abi.encode(orderRoot_, abi.encodePacked(address(_receptor)));
        vmMessage.hash = hash_;
        vmMessage.emitterChainId = MOCK_CHAIN_ID;
        vmMessage.emitterAddress = bytes32(abi.encodePacked(_relayer));

        bytes[] memory whMessages_ = new bytes[](1);
        whMessages_[0] = abi.encode(1);

        vm.mockCall(
            _wormhole,
            0,
            abi.encodeWithSelector(IWormhole.parseAndVerifyVM.selector, whMessages_[0]),
            abi.encode(vmMessage, true, "")
        );

        vm.expectRevert(abi.encodeWithSelector(IWormholeReceptor.InvalidEmitterError.selector));

        // Act + Assert
        vm.prank(_relayer);
        WormholeReceptor(_receptor).receiveWormholeMessages(whMessages_, whMessages_);
    }

    function test_receiveWormholeMessages_AlreadyProcessedError(uint256 orderRoot_, bytes32 hash_) public {
        // Arrange
        IWormhole.VM memory vmMessage;
        vmMessage.payload = abi.encode(orderRoot_, abi.encodePacked(address(_receptor)));
        vmMessage.hash = hash_;
        vmMessage.emitterChainId = MOCK_CHAIN_ID;
        vmMessage.emitterAddress = bytes32(abi.encodePacked(address(_receptor)));

        bytes[] memory whMessages_ = new bytes[](1);
        whMessages_[0] = abi.encode(1);

        vm.mockCall(
            _wormhole,
            0,
            abi.encodeWithSelector(IWormhole.parseAndVerifyVM.selector, whMessages_[0]),
            abi.encode(vmMessage, true, "")
        );

        // Act + Assert
        vm.prank(_relayer);
        WormholeReceptor(_receptor).receiveWormholeMessages(whMessages_, whMessages_);

        vm.expectRevert(abi.encodeWithSelector(IWormholeReceptor.AlreadyProcessedError.selector));

        vm.prank(_relayer);
        WormholeReceptor(_receptor).receiveWormholeMessages(whMessages_, whMessages_);
    }

    function test_receiveWormholeMessages_NotIntendedRecipientError(uint256 orderRoot_, bytes32 hash_) public {
        // Arrange
        IWormhole.VM memory vmMessage;
        vmMessage.payload = abi.encode(orderRoot_, abi.encodePacked(_wormhole));
        vmMessage.hash = hash_;
        vmMessage.emitterChainId = MOCK_CHAIN_ID;
        vmMessage.emitterAddress = bytes32(abi.encodePacked(address(_receptor)));

        bytes[] memory whMessages_ = new bytes[](1);
        whMessages_[0] = abi.encode(1);

        vm.mockCall(
            _wormhole,
            0,
            abi.encodeWithSelector(IWormhole.parseAndVerifyVM.selector, whMessages_[0]),
            abi.encode(vmMessage, true, "")
        );

        vm.expectRevert(abi.encodeWithSelector(IWormholeReceptor.NotIntendedRecipientError.selector));

        // Act + Assert
        vm.prank(_relayer);
        WormholeReceptor(_receptor).receiveWormholeMessages(whMessages_, whMessages_);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _constructor(address owner_, address wormhole_, address relayer_, address bridge_)
        internal
        returns (address receptor_)
    {
        // Arrange
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(address(0), owner_);
        vm.expectEmit(true, false, false, true);
        emit LogSetBridge(bridge_);

        // Act + Assert
        vm.prank(owner_);
        receptor_ = address(new WormholeReceptor(wormhole_, relayer_,bridge_));
        assertEq(address(WormholeReceptor(receptor_).wormhole()), wormhole_);
    }

    function _setTrustedRemote(address owner_, address, address receptor_) internal {
        // Arrange
        bytes memory path_ = abi.encodePacked(receptor_);
        vm.expectEmit(true, true, false, true, receptor_);
        emit LogSetTrustedRemote(MOCK_CHAIN_ID, path_);

        // Act + Assert
        vm.prank(owner_);
        IWormholeBase(receptor_).setTrustedRemote(MOCK_CHAIN_ID, path_);
        assertEq(IWormholeBase(receptor_).isTrustedRemote(MOCK_CHAIN_ID, path_), true);
    }

    function _acceptBridgeRole(address receptor_) internal {
        // Arrange
        vm.expectEmit(false, false, false, true, receptor_);
        emit LogBridgeRoleAccepted();

        // Act + Assert
        IWormholeReceptor(receptor_).acceptBridgeRole();
    }

    function _setOrderRoot(address owner_, address receptor_, uint256 orderRoot_) internal {
        // Arrange
        vm.expectEmit(true, false, false, true, receptor_);
        emit LogOrderRootUpdate(orderRoot_);

        vm.prank(owner_);
        IWormholeReceptor(receptor_).setOrderRoot();
    }

    function _wormholeReceive(address receptor_, uint256 orderRoot_, bytes[] memory whMessages_) internal {
        // Arrange
        vm.expectEmit(true, false, false, true, receptor_);
        emit LogRootReceived(orderRoot_);

        // Act + Assert
        vm.prank(_relayer);
        WormholeReceptor(receptor_).receiveWormholeMessages(whMessages_, whMessages_);
    }

    function _owner() internal pure returns (address) {
        return vm.addr(1337);
    }

    function _intruder() internal pure returns (address) {
        return vm.addr(999);
    }
}
