// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { IWormhole } from "src/dependencies/wormhole/interfaces/IWormhole.sol";
import { ICoreRelayer } from "src/dependencies/wormhole/interfaces/ICoreRelayer.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { WormholeTransmitter } from "src/interoperability/WormholeTransmitter.sol";
import { WormholeBase } from "src/interoperability/wormhole/WormholeBase.sol";
import { IWormholeTransmitter } from "src/interfaces/interoperability/IWormholeTransmitter.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { IWormholeBase } from "src/interfaces/interoperability/wormhole/IWormholeBase.sol";
import { IStarkEx } from "src/interfaces/interoperability/IStarkEx.sol";
import { CoreRelayerMock } from "test/mocks/wormhole/CoreRelayerMock.sol";

contract WormholeTransmitterTest is Test {
    uint16 private constant MOCK_CHAIN_ID = 1337;

    WormholeTransmitter private _transmitter;
    CoreRelayerMock private _relayer;
    address private _wormhole = vm.addr(1);
    address private _provider = vm.addr(2);
    address private _receptor = vm.addr(3);
    address private _starkEx = vm.addr(4);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event LogSetStarkExAddress(address indexed starkEx);
    event LogNewOrderRootSent(uint16 indexed dstChainId, uint256 indexed sequenceNumber, bytes indexed orderRoot);
    event LogSetTrustedRemote(uint16 indexed remoteChainId, bytes indexed path);
    event test();

    function setUp() public {
        vm.label(_owner(), "owner");
        vm.label(_intruder(), "intruder");
        vm.label(_keeper(), "keeper");
        vm.label(_wormhole, "wormhole");
        vm.label(_provider, "provider");
        vm.label(_starkEx, "starkEx");
        vm.label(_receptor, "receptor");

        vm.etch(_starkEx, "Add Code or it reverts");
        vm.etch(_wormhole, "Add Code or it reverts");

        _relayer = new CoreRelayerMock(_provider);
        _transmitter = WormholeTransmitter(_constructor(_owner(), _wormhole, address(_relayer), _starkEx));

        _setTrustedRemote(_owner(), _receptor, address(_transmitter), MOCK_CHAIN_ID);
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
        vm.expectRevert(abi.encodeWithSelector(IWormholeTransmitter.ZeroWormholeAddressError.selector));

        // Act + Assert
        new WormholeTransmitter(wormhole, address(_relayer), _starkEx);
    }

    function test_constructor_ZeroRelayerAddressError() public {
        // Arrange
        address relayer = address(0);
        vm.expectRevert(abi.encodeWithSelector(IWormholeTransmitter.ZeroRelayerAddressError.selector));

        // Act + Assert
        new WormholeTransmitter(_wormhole, relayer, _starkEx);
    }

    function test_constructor_ZeroStarkExAddressError() public {
        // Arrange
        address starkEx = address(0);
        vm.expectRevert(abi.encodeWithSelector(IWormholeTransmitter.ZeroStarkExAddressError.selector));

        // Act + Assert
        new WormholeTransmitter(_wormhole, address(_relayer), starkEx);
    }

    //==============================================================================//
    //=== setTrustedRemote Tests                                                 ===//
    //==============================================================================//

    function test_setTrustedRemote_ok() public {
        // Act + Assert
        _setTrustedRemote(_owner(), _receptor, address(_transmitter), MOCK_CHAIN_ID);
    }

    function test_setTrustedRemote_onlyOwner() public {
        // Arrange
        vm.expectRevert("Ownable: caller is not the owner");

        // Act + Assert
        vm.prank(_intruder());
        _transmitter.setTrustedRemote(MOCK_CHAIN_ID, abi.encode(0));
    }

    //==============================================================================//
    //=== keep Tests                                                             ===//
    //==============================================================================//

    function test_keep_ok(uint256 sequenceNumber_, uint256 orderRoot_, uint256 nativeFee_) public {
        vm.assume(sequenceNumber_ > 0);

        // Arrange
        vm.deal(_keeper(), nativeFee_);
        // And
        _keep(MOCK_CHAIN_ID, sequenceNumber_, orderRoot_, nativeFee_);
    }

    function test_keep_StaleUpdateError() public {
        // Arrange
        vm.deal(_keeper(), 100 ether);
        // And
        uint256 sequenceNumber_ = 0;
        // And
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        vm.expectRevert(
            abi.encodeWithSelector(IWormholeTransmitter.StaleUpdateError.selector, MOCK_CHAIN_ID, sequenceNumber_)
        );

        // Act + Assert
        vm.prank(_keeper());
        _transmitter.keep(MOCK_CHAIN_ID, payable(_keeper()));
    }

    function test_keep_RemoteChainNotTrustedError(uint256 sequenceNumber_, uint256 orderRoot_, uint256 nativeFee_)
        public
    {
        vm.assume(sequenceNumber_ > 0);

        // Arrange
        vm.deal(_keeper(), nativeFee_);
        // And
        bytes memory path_;
        vm.prank(_owner());
        IWormholeBase(_transmitter).setTrustedRemote(MOCK_CHAIN_ID, path_);
        // And
        vm.expectRevert(abi.encodeWithSelector(IWormholeBase.RemoteChainNotTrustedError.selector));
        // And
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        _mock_starkEx_getOrderRoot(orderRoot_);
        // And
        _mock_wormhole_send(orderRoot_, 0);

        // Act + Assert
        vm.prank(_keeper());
        _transmitter.keep{ value: nativeFee_ }(MOCK_CHAIN_ID, payable(_keeper()));
    }

    //==============================================================================//
    //=== batchKeep Tests                                                        ===//
    //==============================================================================//

    function test_batchKeep_ok(uint256 sequenceNumber_, uint256 orderRoot_) public {
        vm.assume(sequenceNumber_ > 0);

        // Arrange
        uint256 totalValue = 1 ether;
        vm.deal(_keeper(), totalValue);
        // And
        uint16[] memory dstChainIds_ = new uint16[](3);
        dstChainIds_[0] = MOCK_CHAIN_ID;
        dstChainIds_[1] = MOCK_CHAIN_ID + 1;
        dstChainIds_[2] = MOCK_CHAIN_ID + 2;
        // And
        uint256[] memory nativeFees_ = new uint256[](3);
        nativeFees_[0] = 0.2 ether;
        nativeFees_[1] = 0.3 ether;
        nativeFees_[2] = 0.5 ether;
        // And
        for (uint256 i = 1; i < dstChainIds_.length; i++) {
            // dstChainIds_[0] is already trusted
            _setTrustedRemote(_owner(), _receptor, address(_transmitter), dstChainIds_[i]);
        }
        // And
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        _mock_starkEx_getOrderRoot(orderRoot_);
        // And
        for (uint256 i_ = 0; i_ < dstChainIds_.length; i_++) {
            _mock_wormhole_send(orderRoot_, i_);
        }
        // And
        for (uint256 i_ = 0; i_ < dstChainIds_.length; i_++) {
            vm.expectEmit(true, true, true, true, address(_transmitter));
            emit LogNewOrderRootSent(dstChainIds_[i_], sequenceNumber_, abi.encode(orderRoot_));
        }

        // Act + Assert
        _transmitter.batchKeep{ value: totalValue }(dstChainIds_, nativeFees_, payable(_keeper()));
    }

    function test_batchKeep_StaleUpdateError(uint256 sequenceNumber_, uint256 orderRoot_) public {
        vm.assume(sequenceNumber_ > 0);

        // Arrange
        uint256 totalValue = 1 ether;
        vm.deal(_keeper(), totalValue);
        // And
        uint16[] memory dstChainIds_ = new uint16[](3);
        dstChainIds_[0] = MOCK_CHAIN_ID;
        dstChainIds_[1] = MOCK_CHAIN_ID + 1;
        dstChainIds_[2] = MOCK_CHAIN_ID + 2;
        // And
        uint256[] memory nativeFees_ = new uint256[](3);
        nativeFees_[0] = 0.2 ether;
        nativeFees_[1] = 0.3 ether;
        nativeFees_[2] = 0.5 ether;
        // And
        for (uint256 i = 1; i < dstChainIds_.length; i++) {
            // dstChainIds_[0] is already trusted.
            _setTrustedRemote(_owner(), _receptor, address(_transmitter), dstChainIds_[i]);
        }
        // And
        vm.deal(_keeper(), nativeFees_[2]); //Add extra ether to keeper to keep chain dstChainIds_[2].
        _keep(dstChainIds_[2], sequenceNumber_, orderRoot_, nativeFees_[2]);
        // And
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        _mock_starkEx_getOrderRoot(orderRoot_);
        // And
        for (uint256 i_ = 0; i_ < dstChainIds_.length - 1; i_++) {
            // Last chain will not be called because of stale Update Error.
            _mock_wormhole_send(orderRoot_, i_ + 1);
        }
        // And
        vm.expectRevert(
            abi.encodeWithSelector(IWormholeTransmitter.StaleUpdateError.selector, dstChainIds_[2], sequenceNumber_)
        );

        // Act + Assert
        _transmitter.batchKeep{ value: totalValue }(dstChainIds_, nativeFees_, payable(_keeper()));
    }

    function test_batchKeep_InvalidEtherSentError() public {
        // Arrange
        uint256 totalValue = 1 ether;
        vm.deal(_keeper(), totalValue);
        // And
        uint16[] memory dstChainIds_ = new uint16[](3);
        dstChainIds_[0] = MOCK_CHAIN_ID;
        dstChainIds_[1] = MOCK_CHAIN_ID + 1;
        dstChainIds_[2] = MOCK_CHAIN_ID + 2;
        // And
        uint256[] memory nativeFees_ = new uint256[](3);
        nativeFees_[0] = 0.2 ether;
        nativeFees_[1] = 0.3 ether;
        nativeFees_[2] = 0.5 ether;
        // And
        vm.expectRevert(abi.encodeWithSelector(IWormholeTransmitter.InvalidEtherSentError.selector));

        // Act + Assert
        _transmitter.batchKeep{ value: totalValue - 1 }(dstChainIds_, nativeFees_, payable(_keeper()));
    }

    function test_batchKeep_RemoteChainNotTrustedError(uint256 sequenceNumber_, uint256 orderRoot_) public {
        vm.assume(sequenceNumber_ > 0);

        // Arrange
        uint256 totalValue = 1 ether;
        vm.deal(_keeper(), totalValue);
        // And
        uint16[] memory dstChainIds_ = new uint16[](3);
        dstChainIds_[0] = MOCK_CHAIN_ID;
        dstChainIds_[1] = MOCK_CHAIN_ID + 1;
        dstChainIds_[2] = MOCK_CHAIN_ID + 2;
        // And
        uint256[] memory nativeFees_ = new uint256[](3);
        nativeFees_[0] = 0.2 ether;
        nativeFees_[1] = 0.3 ether;
        nativeFees_[2] = 0.5 ether;
        // And
        for (uint256 i = 1; i < dstChainIds_.length; i++) {
            // dstChainIds_[0] is already trusted
            _setTrustedRemote(_owner(), _receptor, address(_transmitter), dstChainIds_[i]);
        }
        // And
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        _mock_starkEx_getOrderRoot(orderRoot_);
        // And
        for (uint256 i_ = 0; i_ < dstChainIds_.length; i_++) {
            _mock_wormhole_send(orderRoot_, i_);
        }
        // And
        bytes memory path_;
        vm.startPrank(_owner());
        IWormholeBase(_transmitter).setTrustedRemote(MOCK_CHAIN_ID, path_);
        IWormholeBase(_transmitter).setTrustedRemote(MOCK_CHAIN_ID + 1, path_);
        IWormholeBase(_transmitter).setTrustedRemote(MOCK_CHAIN_ID + 2, path_);
        vm.stopPrank();
        // And
        vm.expectRevert(abi.encodeWithSelector(IWormholeBase.RemoteChainNotTrustedError.selector));

        // Act + Assert
        _transmitter.batchKeep{ value: totalValue }(dstChainIds_, nativeFees_, payable(_keeper()));
    }

    //==============================================================================//
    //=== getPayload Tests                                                       ===//
    //==============================================================================//

    function test_getPayload_ok(uint256 expectedOrderRoot_) public {
        // Arrange
        _mock_starkEx_getOrderRoot(expectedOrderRoot_);

        // Act + Assert
        assertEq(keccak256(_transmitter.getPayload()), keccak256(abi.encode(expectedOrderRoot_)));
    }

    //==============================================================================//
    //=== getWormholeFee Tests                                                  ===//
    //==============================================================================//

    function test_getWormholeFee_ok(uint256 expectedNativeFee_) public {
        // Arrange
        vm.mockCall(
            _wormhole, 0, abi.encodeWithSelector(IWormhole.messageFee.selector), abi.encode(expectedNativeFee_, 0)
        );

        // Act
        (uint256 returnedNativeFee_) = _transmitter.getWormholeFee(MOCK_CHAIN_ID);

        // Assert
        assertEq(returnedNativeFee_, (expectedNativeFee_));
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _constructor(address owner_, address wormhole_, address relayer_, address starkEx_)
        internal
        returns (address transmitter_)
    {
        // Arrange
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(address(0), owner_);
        vm.expectEmit(true, false, false, true);
        emit LogSetStarkExAddress(starkEx_);

        // Act + Assert
        vm.prank(owner_);
        transmitter_ = address(new WormholeTransmitter(wormhole_, relayer_, starkEx_));
        assertEq(address(WormholeTransmitter(transmitter_).wormhole()), wormhole_);
    }

    function _setTrustedRemote(address owner_, address receptor_, address transmitter_, uint16 srcChainId_) internal {
        // Arrange
        bytes memory path_ = abi.encodePacked(receptor_);
        vm.expectEmit(true, true, false, true, transmitter_);
        emit LogSetTrustedRemote(srcChainId_, path_);

        // Act + Assert
        vm.prank(owner_);
        IWormholeBase(transmitter_).setTrustedRemote(srcChainId_, path_);
        assertEq(IWormholeBase(transmitter_).isTrustedRemote(srcChainId_, path_), true);
    }

    function _keep(uint16 dstChainId_, uint256 sequenceNumber_, uint256 orderRoot_, uint256 nativeFee_) public {
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        _mock_starkEx_getOrderRoot(orderRoot_);
        // And
        _mock_wormhole_send(orderRoot_, 0);
        // And
        vm.expectEmit(true, true, true, true, address(_transmitter));
        emit LogNewOrderRootSent(dstChainId_, sequenceNumber_, abi.encode(orderRoot_));

        // Act + Assert
        vm.prank(_keeper());
        _transmitter.keep{ value: nativeFee_ }(dstChainId_, payable(_keeper()));
    }

    function _mock_starkEx_getSequenceNumber(uint256 returnedSequenceNumber_) internal {
        vm.mockCall(
            _starkEx,
            0,
            abi.encodeWithSelector(IStarkEx.getSequenceNumber.selector),
            abi.encode(returnedSequenceNumber_)
        );
    }

    function _mock_wormhole_send(uint256 orderRoot_, uint256 nonce_) internal {
        bytes memory payload = abi.encode(orderRoot_, abi.encodePacked(_receptor));

        vm.mockCall(_wormhole, 0, abi.encodeWithSelector(IWormhole.messageFee.selector), abi.encode(0));
        vm.mockCall(
            _wormhole,
            0,
            abi.encodeWithSelector(IWormhole.publishMessage.selector, nonce_, payload, 1),
            abi.encode(uint64(0))
        );
    }

    function _mock_starkEx_getOrderRoot(uint256 returnedOrderRoot_) internal {
        vm.mockCall(_starkEx, 0, abi.encodeWithSelector(IStarkEx.getOrderRoot.selector), abi.encode(returnedOrderRoot_));
    }

    function _owner() internal pure returns (address) {
        return vm.addr(1337);
    }

    function _intruder() internal pure returns (address) {
        return vm.addr(999);
    }

    function _keeper() internal pure returns (address) {
        return vm.addr(978);
    }
}
