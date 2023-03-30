// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";

import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { ILzReceptor } from "src/interfaces/interoperability/ILzReceptor.sol";
import { ILzBase } from "src/interfaces/interoperability/lz/ILzBase.sol";
import { ILzReceiver } from "src/interfaces/interoperability/lz/ILzReceiver.sol";
import { LzReceptor } from "src/interoperability/LzReceptor.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { IMultiBridgeReceptor } from "src/interfaces/interoperability/IMultiBridgeReceptor.sol";

contract LzReceptorTest is Test {
    uint16 private constant MOCK_CHAIN_ID = 1337;

    LzReceptor private _receptor;
    address private _lzEndpoint = vm.addr(1);
    address private _bridge = vm.addr(2);
    address private _transmitter = vm.addr(3);

    event LogSetMultiBridgeAddress(address indexed bridge);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event LogSetTrustedRemote(uint16 indexed remoteChainId, bytes indexed path);
    event LogBridgeRoleAccepted();
    event LogRootReceived(bytes indexed payload);
    event LogOutdatedRootReceived(uint256 indexed orderRoot, uint64 indexed nonce);
    event LogOrderRootUpdate(uint256 indexed orderRoot);
    event LogMessageFailed(
        uint16 indexed srcChainId, bytes indexed path, uint64 indexed nonce, bytes payload, bytes reason
    );

    function setUp() public {
        vm.label(_owner(), "owner");
        vm.label(_intruder(), "intruder");
        vm.label(_lzEndpoint, "lzEndpoint");
        vm.label(_bridge, "bridge");
        vm.label(_transmitter, "transmitter");

        _receptor = LzReceptor(_constructor(_owner(), _lzEndpoint, _bridge));
        _setTrustedRemote(_owner(), _transmitter, address(_receptor));
    }

    //==============================================================================//
    //=== constructor Tests                                                      ===//
    //==============================================================================//

    function test_constructor_ok(address lzEndpoint_, address bridge_) public {
        vm.assume(lzEndpoint_ > address(0));
        vm.assume(bridge_ > address(0));

        // Arrange
        vm.label(lzEndpoint_, "lzEndpoint");
        vm.label(bridge_, "bridge");

        // Act + Assert
        _constructor(_owner(), lzEndpoint_, bridge_);
    }

    function test_constructor_ZeroLzEndpointAddressError() public {
        // Arrange
        address lzEndpoint_ = address(0);
        vm.expectRevert(abi.encodeWithSelector(ILzReceptor.ZeroLzEndpointAddressError.selector));

        // Act + Assert
        new LzReceptor(lzEndpoint_, _bridge);
    }

    function test_constructor_ZeroMultiBridgeAddressError() public {
        // Arrange
        address bridge_ = address(0);
        vm.expectRevert(abi.encodeWithSelector(ILzReceptor.ZeroMultiBridgeAddressError.selector));

        // Act + Assert
        new LzReceptor(_lzEndpoint, bridge_);
    }

    //==============================================================================//
    //=== setMultiBridgeAddress Tests                                            ===//
    //==============================================================================//

    function test_setMultiBridgeAddress_ok(address bridge_) public {
        // Arrange
        vm.assume(bridge_ > address(0));
        // And
        vm.expectEmit(true, false, false, true, address(_receptor));
        emit LogSetMultiBridgeAddress(bridge_);

        // Act + Assert
        vm.prank(_owner());
        _receptor.setMultiBridgeAddress(bridge_);
        assertEq(_receptor.getMultiBridgeAddress(), bridge_);
    }

    function test_setMultiBridgeAddress_ZeroMultiBridgeAddressError() public {
        // Arrange
        address bridge_ = address(0);
        vm.expectRevert(abi.encodeWithSelector(ILzReceptor.ZeroMultiBridgeAddressError.selector));

        // Act + Assert
        vm.prank(_owner());
        _receptor.setMultiBridgeAddress(bridge_);
    }

    function test_setMultiBridgeAddress_onlyOwner() public {
        // Arrange
        address bridge_ = address(1);
        // And
        vm.expectRevert("Ownable: caller is not the owner");

        // Act + Assert
        vm.prank(_intruder());
        _receptor.setMultiBridgeAddress(bridge_);
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
    //=== nonBlockingLzReceive Tests                                             ===//
    //==============================================================================//

    function test_nonBlockingLzReceive_ok(uint64 nonce_, uint256 orderRoot_) public {
        vm.assume(nonce_ > 0);

        // Arrange
        bytes memory path_ = abi.encodePacked(_transmitter, address(_receptor));

        // Act + Assert
        _lzReceive(address(_receptor), _lzEndpoint, MOCK_CHAIN_ID, path_, nonce_, orderRoot_);
    }

    function test_nonBlockingLzReceive_RemoteChainNotSecureError(uint16 srcChaindId_, bytes memory path_) public {
        vm.assume(keccak256(path_) != keccak256(abi.encodePacked(_transmitter, address(_receptor))));

        // Arrange
        uint64 nonce_ = 1;
        uint256 orderRoot_ = 0;
        bytes memory payload_ = abi.encode(orderRoot_);
        vm.expectRevert(abi.encodeWithSelector(ILzBase.RemoteChainNotTrustedError.selector));

        // Act + Assert
        vm.prank(_lzEndpoint);
        LzReceptor(_receptor).lzReceive(srcChaindId_, path_, nonce_, payload_);
    }

    function test_nonBlockingLzReceive_InvalidEndpointCallerError() public {
        // Arrange
        uint64 nonce_ = 1;
        uint256 orderRoot_ = 0;
        bytes memory path_ = abi.encodePacked(_transmitter, address(_receptor));
        bytes memory payload_ = abi.encode(orderRoot_);
        vm.expectRevert(abi.encodeWithSelector(ILzReceiver.InvalidEndpointCallerError.selector));

        // Act + Assert
        vm.prank(_intruder());
        LzReceptor(_receptor).lzReceive(MOCK_CHAIN_ID, path_, nonce_, payload_);
    }

    function test_nonBlockingLzReceive_messageFail_wrongPayload() public {
        // Arrange
        // Wrong payload will make message revert.
        bytes memory payload_ = "";
        bytes memory path_ = abi.encodePacked(_transmitter, address(_receptor));
        uint64 nonce_ = 1;

        // Act + Assert
        vm.prank(_lzEndpoint);
        vm.expectEmit(true, true, false, true, address(_receptor));
        emit LogMessageFailed(MOCK_CHAIN_ID, path_, nonce_, payload_, "");
        _receptor.lzReceive(MOCK_CHAIN_ID, path_, nonce_, payload_);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _constructor(address owner_, address lzEndpoint_, address bridge_) internal returns (address receptor_) {
        // Arrange
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(address(0), owner_);
        vm.expectEmit(true, false, false, true);
        emit LogSetMultiBridgeAddress(bridge_);

        // Act + Assert
        vm.prank(owner_);
        receptor_ = address(new LzReceptor(lzEndpoint_, bridge_));
        assertEq(address(LzReceptor(receptor_).lzEndpoint()), lzEndpoint_);
    }

    function _setTrustedRemote(address owner_, address transmitter_, address receptor_) internal {
        // Arrange
        bytes memory path_ = abi.encodePacked(transmitter_, receptor_);
        vm.expectEmit(true, true, false, true, receptor_);
        emit LogSetTrustedRemote(MOCK_CHAIN_ID, path_);

        // Act + Assert
        vm.prank(owner_);
        ILzBase(receptor_).setTrustedRemote(MOCK_CHAIN_ID, path_);
        assertEq(ILzBase(receptor_).isTrustedRemote(MOCK_CHAIN_ID, path_), true);
    }

    function _lzReceive(
        address receptor_,
        address lzEndpoint_,
        uint16 srcChaindId_,
        bytes memory path_,
        uint64 nonce_,
        uint256 orderRoot_
    ) internal {
        // Arrange
        bytes memory payload_ = abi.encode(abi.encode(orderRoot_), nonce_);
        vm.expectEmit(true, false, false, true, receptor_);
        emit LogRootReceived(payload_);
        // And
        vm.mockCall(
            _bridge,
            abi.encodeWithSelector(IMultiBridgeReceptor.receiveRoot.selector, payload_, srcChaindId_),
            abi.encode("")
        );

        // Act + Assert
        vm.prank(lzEndpoint_);
        LzReceptor(receptor_).lzReceive(srcChaindId_, path_, nonce_, payload_);
    }

    function _owner() internal pure returns (address) {
        return vm.addr(1337);
    }

    function _intruder() internal pure returns (address) {
        return vm.addr(999);
    }
}
