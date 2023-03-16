// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { IMessageBus } from "src/dependencies/celer/interfaces/IMessageBus.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { CelerReceptor } from "src/interoperability/CelerReceptor.sol";
import { CelerBase } from "src/interoperability/celer/CelerBase.sol";
import { ICelerReceptor } from "src/interfaces/interoperability/ICelerReceptor.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { ICelerBase } from "src/interfaces/interoperability/celer/ICelerBase.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";

contract CelerReceptorTest is Test {
    uint16 private constant MOCK_CHAIN_ID = 1337;

    CelerReceptor private _receptor;
    address private _messageBus = vm.addr(1);
    address private _bridge = vm.addr(2);
    address private _transmitter = vm.addr(3);

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
        vm.label(_messageBus, "messageBus");
        vm.label(_transmitter, "transmitter");

        vm.etch(_messageBus, "Add Code or it reverts");

        _receptor = CelerReceptor(_constructor(_owner(), _messageBus, _bridge));
        _setTrustedRemote(_owner(), _transmitter, address(_receptor));
    }

    //==============================================================================//
    //=== constructor Tests                                                      ===//
    //==============================================================================//
    
    function test_constructor_ok(address messageBus_, address starkEx_) public {
        vm.assume(messageBus_ > address(0));
        vm.assume(starkEx_ > address(0));

        // Arrange
        vm.label(messageBus_, "messageBus");
        vm.label(starkEx_, "bridge");

        // Act + Assert
        _constructor(_owner(), messageBus_, starkEx_);
    }
    
    function test_constructor_ZeroCelerAddressError() public {
        // Arrange
        address messageBus_ = address(0);
        vm.expectRevert(abi.encodeWithSelector(ICelerReceptor.ZeroCelerAddressError.selector));

        // Act + Assert
        new CelerReceptor(messageBus_, _bridge);
    }

    function test_constructor_ZeroBridgeAddressError() public {
        // Arrange
        address bridge_ = address(0);
        vm.expectRevert(abi.encodeWithSelector(ICelerReceptor.ZeroBridgeAddressError.selector));

        // Act + Assert
        new CelerReceptor(_messageBus, bridge_);
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
    //=== executeMessage Tests                                          ===//
    //==============================================================================//
    
    function test_executeMessage_ok(uint256 orderRoot_) public {
        // Arrange
        vm.expectEmit(true, false, false, true, address(_receptor));
        emit LogRootReceived(orderRoot_);

        bytes memory payload_ = abi.encode(orderRoot_, abi.encodePacked(address(_receptor)));

        // Act + Assert
        vm.prank(_messageBus);
        CelerReceptor(address(_receptor)).executeMessage(_transmitter, MOCK_CHAIN_ID, payload_, address(0x0));
    }
    
    function test_executeMessage_InvalidCallerError(uint256 orderRoot_) public {
        // Arrange
        bytes memory payload_ = abi.encode(orderRoot_, abi.encodePacked(address(_receptor)));

        vm.expectRevert(abi.encodeWithSelector(ICelerReceptor.InvalidCallerError.selector));

        // Act + Assert
        vm.prank(_transmitter);
        CelerReceptor(address(_receptor)).executeMessage(_transmitter, MOCK_CHAIN_ID, payload_, address(0x0));
    }
    
    function test_executeMessage_InvalidEmitterError(uint256 orderRoot_) public {
        // Arrange
        bytes memory payload_ = abi.encode(orderRoot_, abi.encodePacked(address(_receptor)));

        vm.expectRevert(abi.encodeWithSelector(ICelerReceptor.InvalidEmitterError.selector));

        // Act + Assert
        vm.prank(_messageBus);
        CelerReceptor(address(_receptor)).executeMessage(_messageBus, MOCK_CHAIN_ID, payload_, address(0x0));
    }
    
    function test_executeMessage_NotIntendedRecipientError(uint256 orderRoot_) public {
        // Arrange
        bytes memory payload_ = abi.encode(orderRoot_, abi.encodePacked(address(_messageBus)));

        vm.expectRevert(abi.encodeWithSelector(ICelerReceptor.NotIntendedRecipientError.selector));

        // Act + Assert
        vm.prank(_messageBus);
        CelerReceptor(address(_receptor)).executeMessage(_transmitter, MOCK_CHAIN_ID, payload_, address(0x0));
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//
    
    function _constructor(address owner_, address messageBus_, address bridge_)
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
        receptor_ = address(new CelerReceptor(messageBus_,bridge_));
        assertEq(address(CelerReceptor(receptor_).messageBus()), messageBus_);
    }

    function _setTrustedRemote(address owner_, address transmitter_, address receptor_) internal {
        // Arrange
        bytes memory path_ = abi.encodePacked(transmitter_);
        vm.expectEmit(true, true, false, true, receptor_);
        emit LogSetTrustedRemote(MOCK_CHAIN_ID, path_);

        // Act + Assert
        vm.prank(owner_);
        ICelerBase(receptor_).setTrustedRemote(MOCK_CHAIN_ID, path_);
        assertEq(ICelerBase(receptor_).isTrustedRemote(MOCK_CHAIN_ID, path_), true);
    }
    
    function _acceptBridgeRole(address receptor_) internal {
        // Arrange
        vm.expectEmit(false, false, false, true, receptor_);
        emit LogBridgeRoleAccepted();

        // Act + Assert
        ICelerReceptor(receptor_).acceptBridgeRole();
    }
    
    function _setOrderRoot(address owner_, address receptor_, uint256 orderRoot_) internal {
        // Arrange
        vm.expectEmit(true, false, false, true, receptor_);
        emit LogOrderRootUpdate(orderRoot_);

        vm.prank(owner_);
        ICelerReceptor(receptor_).setOrderRoot();
    }
    
    function _owner() internal pure returns (address) {
        return vm.addr(1337);
    }

    function _intruder() internal pure returns (address) {
        return vm.addr(999);
    }
}
