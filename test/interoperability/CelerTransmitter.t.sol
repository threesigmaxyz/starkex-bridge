// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { IMessageBus } from "src/dependencies/celer/interfaces/IMessageBus.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { CelerTransmitter } from "src/interoperability/CelerTransmitter.sol";
import { CelerBase } from "src/interoperability/celer/CelerBase.sol";
import { ICelerTransmitter } from "src/interfaces/interoperability/ICelerTransmitter.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { ICelerBase } from "src/interfaces/interoperability/celer/ICelerBase.sol";
import { IStarkEx } from "src/interfaces/interoperability/IStarkEx.sol";

contract CelerTransmitterTest is Test {
    uint16 private constant MOCK_CHAIN_ID = 1337;

    CelerTransmitter private _transmitter;
    address private _messageBus = vm.addr(1);
    address private _receptor = vm.addr(3);
    address private _starkEx = vm.addr(4);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event LogSetStarkExAddress(address indexed starkEx);
    event LogNewOrderRootSent(uint16 indexed dstChainId, uint256 indexed sequenceNumber, bytes indexed orderRoot);
    event LogSetTrustedRemote(uint16 indexed remoteChainId, bytes indexed path);
    event test(bytes test);

    function setUp() public {
        vm.label(_owner(), "owner");
        vm.label(_intruder(), "intruder");
        vm.label(_keeper(), "keeper");
        vm.label(_messageBus, "messageBus");
        vm.label(_starkEx, "starkEx");
        vm.label(_receptor, "receptor");

        vm.etch(_starkEx, "Add Code or it reverts");
        vm.etch(_messageBus, "Add Code or it reverts");

        _transmitter = CelerTransmitter(_constructor(_owner(), _messageBus, _starkEx));

        _setTrustedRemote(_owner(), _receptor, address(_transmitter), MOCK_CHAIN_ID);
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
        vm.expectRevert(abi.encodeWithSelector(ICelerTransmitter.ZeroCelerAddressError.selector));

        // Act + Assert
        new CelerTransmitter(messageBus_, _starkEx);
    }

    function test_constructor_ZeroStarkExAddressError() public {
        // Arrange
        address starkEx = address(0);
        vm.expectRevert(abi.encodeWithSelector(ICelerTransmitter.ZeroStarkExAddressError.selector));

        // Act + Assert
        new CelerTransmitter(_messageBus, starkEx);
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
            abi.encodeWithSelector(ICelerTransmitter.StaleUpdateError.selector, MOCK_CHAIN_ID, sequenceNumber_)
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
        ICelerBase(_transmitter).setTrustedRemote(MOCK_CHAIN_ID, path_);
        // And
        vm.expectRevert(abi.encodeWithSelector(ICelerBase.RemoteChainNotTrustedError.selector));
        // And
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        _mock_starkEx_getOrderRoot(orderRoot_);
        // And
        _mock_celer_send(MOCK_CHAIN_ID, orderRoot_, 0);

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
            _mock_celer_send(dstChainIds_[i_], orderRoot_, nativeFees_[i_]);
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
            _mock_celer_send(dstChainIds_[i_], orderRoot_, nativeFees_[i_]);
        }
        // And
        vm.expectRevert(
            abi.encodeWithSelector(ICelerTransmitter.StaleUpdateError.selector, dstChainIds_[2], sequenceNumber_)
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
        vm.expectRevert(abi.encodeWithSelector(ICelerTransmitter.InvalidEtherSentError.selector));

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
            _mock_celer_send(dstChainIds_[i_], orderRoot_, nativeFees_[i_]);
        }
        // And
        bytes memory path_;
        vm.startPrank(_owner());
        ICelerBase(_transmitter).setTrustedRemote(MOCK_CHAIN_ID, path_);
        ICelerBase(_transmitter).setTrustedRemote(MOCK_CHAIN_ID + 1, path_);
        ICelerBase(_transmitter).setTrustedRemote(MOCK_CHAIN_ID + 2, path_);
        vm.stopPrank();
        // And
        vm.expectRevert(abi.encodeWithSelector(ICelerBase.RemoteChainNotTrustedError.selector));

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

    function test_getCelerFee_ok(uint256 expectedNativeFee_, bytes memory data_) public {
        // Arrange
        vm.mockCall(
            _messageBus,
            0,
            abi.encodeWithSelector(IMessageBus.calcFee.selector, abi.encode(data_, _receptor)),
            abi.encode(expectedNativeFee_, 0)
        );

        // Act
        (uint256 returnedNativeFee_) = _transmitter.getCelerFee(_receptor, data_);

        // Assert
        assertEq(returnedNativeFee_, (expectedNativeFee_));
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _constructor(address owner_, address messageBus_, address starkEx_)
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
        transmitter_ = address(new CelerTransmitter(messageBus_, starkEx_));
        assertEq(address(CelerTransmitter(transmitter_).messageBus()), messageBus_);
    }

    function _setTrustedRemote(address owner_, address receptor_, address transmitter_, uint16 srcChainId_) internal {
        // Arrange
        bytes memory path_ = abi.encodePacked(receptor_);
        vm.expectEmit(true, true, false, true, transmitter_);
        emit LogSetTrustedRemote(srcChainId_, path_);

        // Act + Assert
        vm.prank(owner_);
        ICelerBase(transmitter_).setTrustedRemote(srcChainId_, path_);
        assertEq(ICelerBase(transmitter_).isTrustedRemote(srcChainId_, path_), true);
    }

    function _keep(uint16 dstChainId_, uint256 sequenceNumber_, uint256 orderRoot_, uint256 nativeFee_) public {
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        _mock_starkEx_getOrderRoot(orderRoot_);
        // And
        _mock_celer_send(dstChainId_, orderRoot_, nativeFee_);
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

    function _mock_celer_send(uint16 dstChainId_, uint256 orderRoot_, uint256 nativeFee_) internal {
        bytes memory payload_ = abi.encode(orderRoot_, abi.encodePacked(_receptor));
        bytes memory path_ = abi.encodePacked(_receptor);

        vm.mockCall(
            _messageBus,
            nativeFee_,
            abi.encodeWithSelector(IMessageBus.sendMessage.selector, path_, dstChainId_, payload_),
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
