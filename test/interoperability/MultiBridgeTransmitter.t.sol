// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";

import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { IStarkEx } from "src/interfaces/interoperability/IStarkEx.sol";

import { MultiBridgeTransmitter } from "src/interoperability/MultiBridgeTransmitter.sol";
import { IMultiBridgeTransmitter } from "src/interfaces/interoperability/IMultiBridgeTransmitter.sol";
import { IBridgeTransmitter } from "src/interfaces/interoperability/IBridgeTransmitter.sol";
import { MockKeeper } from "test/mocks/MockKeeper.sol";

contract MultiBridgeTransmitterTest is Test {
    uint16 private constant MOCK_CHAIN_ID = 1337;

    MultiBridgeTransmitter private _transmitter;
    address private _receptor = vm.addr(1);
    address private _starkEx = vm.addr(2);
    address private _bridge1 = vm.addr(3);
    address private _bridge2 = vm.addr(4);
    address private _bridge3 = vm.addr(5);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event LogSetStarkExAddress(address indexed starkEx);
    event LogTransmitSuccess(
        address indexed bridgeTransmitter, uint16 indexed dstChainId, uint256 sequenceNumber, bytes indexed payload
    );
    event LogTransmitFailed(
        address indexed bridgeTransmitter, uint16 indexed dstChainId, uint256 sequenceNumber, bytes indexed payload
    );
    event LogBatchTransmitSuccess(
        address indexed bridgeTransmitter, uint16[] indexed dstChainId, uint256 sequenceNumber, bytes indexed payload
    );
    event LogBatchTransmitFailed(
        address indexed bridgeTransmitter, uint16[] indexed dstChainId, uint256 sequenceNumber, bytes indexed payload
    );
    event LogNewBridgeAdded(address indexed newBridge);
    event LogBridgeRemoved(address indexed removeBridge);

    function setUp() public {
        vm.label(_owner(), "owner");
        vm.label(_intruder(), "intruder");
        vm.label(_keeper(), "keeper");
        vm.label(_starkEx, "starkEx");
        vm.label(_receptor, "receptor");
        vm.label(_bridge1, "bridge1");
        vm.label(_bridge2, "bridge2");
        vm.label(_bridge3, "bridge3");

        vm.etch(_starkEx, "Add Code or it reverts");
        vm.etch(_bridge1, "Add Code or it reverts");
        vm.etch(_bridge2, "Add Code or it reverts");
        vm.etch(_bridge3, "Add Code or it reverts");

        _transmitter = MultiBridgeTransmitter(_constructor(_owner(), _starkEx));

        address[] memory bridges_ = new address[](3);
        bridges_[0] = _bridge1;
        bridges_[1] = _bridge2;
        bridges_[2] = _bridge3;

        _setBridgeTransmitters(_owner(), bridges_);
    }

    //==============================================================================//
    //=== constructor Tests                                                      ===//
    //==============================================================================//

    function test_constructor_ok(address starkEx_) public {
        vm.assume(starkEx_ > address(0));

        // Arrange
        vm.label(starkEx_, "bridge");

        // Act + Assert
        _constructor(_owner(), starkEx_);
    }

    function test_constructor_ZeroStarkExAddressError() public {
        // Arrange
        address starkEx_ = address(0);
        vm.expectRevert(abi.encodeWithSelector(IBridgeTransmitter.ZeroStarkExAddressError.selector));

        // Act + Assert
        new MultiBridgeTransmitter(starkEx_);
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
    //=== send Tests                                                             ===//
    //==============================================================================//

    function test_send_ok(uint256 sequenceNumber_, uint256 orderRoot_, uint256 nativeFee_) public {
        vm.assume(sequenceNumber_ > 0);

        // Arrange
        vm.deal(_keeper(), nativeFee_);
        // And
        _send(MOCK_CHAIN_ID, sequenceNumber_, orderRoot_, nativeFee_);
    }

    function test_send_StaleUpdateError() public {
        // Arrange
        vm.deal(_keeper(), 100 ether);
        // And
        _mock_starkEx_getOrderRoot(0);
        // And
        uint256 sequenceNumber_ = 0;
        // And
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        vm.expectRevert(
            abi.encodeWithSelector(IBridgeTransmitter.StaleUpdateError.selector, MOCK_CHAIN_ID, sequenceNumber_)
        );

        // Act + Assert
        vm.prank(_keeper());
        _transmitter.send(MOCK_CHAIN_ID, payable(_keeper()));
    }

    function test_send_RefundError() public {
        // Arrange
        MockKeeper mockKeeper_ = new MockKeeper();
        // And
        address[] memory bridges_ = _transmitter.getBridges();
        vm.deal(address(mockKeeper_), 100 ether);
        // And
        _mock_starkEx_getOrderRoot(0);
        // And
        _mock_starkEx_getSequenceNumber(1);
        // And
        _mock_bridge_getFee(MOCK_CHAIN_ID, 0, 1, 10 ether, bridges_);
        // And
        _mock_bridge_keep(MOCK_CHAIN_ID, 0, 1, 10 ether, bridges_);
        // And
        vm.expectRevert(abi.encodeWithSelector(IMultiBridgeTransmitter.RefundError.selector));

        // Act + Assert
        vm.prank(address(mockKeeper_));
        _transmitter.send{ value: 100 ether }(MOCK_CHAIN_ID, payable(address(mockKeeper_)));
    }

    //==============================================================================//
    //=== sendBatch Tests                                                        ===//
    //==============================================================================//

    function test_sendBatch_ok(uint256 sequenceNumber_, uint256 orderRoot_) public {
        vm.assume(sequenceNumber_ > 0);

        // Arrange
        uint256 totalValue = 9 ether;
        vm.deal(_keeper(), totalValue);
        // And
        address[] memory bridges_ = _transmitter.getBridges();
        // And
        uint16[] memory dstChainIds_ = new uint16[](3);
        dstChainIds_[0] = MOCK_CHAIN_ID;
        dstChainIds_[1] = MOCK_CHAIN_ID + 1;
        dstChainIds_[2] = MOCK_CHAIN_ID + 2;
        // And
        uint256[] memory nativeFees_ = new uint256[](3);
        nativeFees_[0] = 3 ether;
        nativeFees_[1] = 3 ether;
        nativeFees_[2] = 3 ether;
        // And
        uint256[] memory fees_ = new uint256[](3);
        fees_[0] = 3 ether / bridges_.length;
        fees_[1] = 3 ether / bridges_.length;
        fees_[2] = 3 ether / bridges_.length;
        // And
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        _mock_starkEx_getOrderRoot(orderRoot_);
        // And
        _mock_bridge_batch_getFee(dstChainIds_, orderRoot_, sequenceNumber_, nativeFees_, bridges_);
        // And
        _mock_bridge_batchKeep(dstChainIds_, orderRoot_, sequenceNumber_, nativeFees_, fees_, bridges_);
        // And
        for (uint256 f_ = 0; f_ < bridges_.length - 1; f_++) {
            // -1 to have a transmit failed example
            vm.expectEmit(true, true, true, true, address(_transmitter));
            emit LogBatchTransmitSuccess(bridges_[f_], dstChainIds_, sequenceNumber_, abi.encode(orderRoot_));
        }
        vm.expectEmit(true, true, true, true, address(_transmitter)); // transmit failed example
        emit LogBatchTransmitFailed(
            bridges_[bridges_.length - 1], dstChainIds_, sequenceNumber_, abi.encode(orderRoot_)
        );

        // Act + Assert
        vm.prank(_keeper());
        _transmitter.sendBatch{ value: totalValue }(dstChainIds_, payable(_keeper()));
    }

    function test_sendBatch_StaleUpdateError() public {
        // Arrange
        uint256 totalValue = 9 ether;
        // And
        address[] memory bridges_ = _transmitter.getBridges();
        // And
        uint16[] memory dstChainIds_ = new uint16[](3);
        dstChainIds_[0] = MOCK_CHAIN_ID;
        dstChainIds_[1] = MOCK_CHAIN_ID + 1;
        dstChainIds_[2] = MOCK_CHAIN_ID + 2;
        // And
        uint256[] memory nativeFees_ = new uint256[](3);
        nativeFees_[0] = 3 ether;
        nativeFees_[1] = 3 ether;
        nativeFees_[2] = 3 ether;
        // And
        uint256[] memory fees_ = new uint256[](3);
        fees_[0] = 3 ether / bridges_.length;
        fees_[1] = 3 ether / bridges_.length;
        fees_[2] = 3 ether / bridges_.length;
        // And
        vm.deal(_keeper(), nativeFees_[2]); //Add extra ether to keeper to keep chain dstChainIds_[2].
        _send(dstChainIds_[2], 1, 0, nativeFees_[2]);
        // And
        _mock_starkEx_getSequenceNumber(1);
        // And
        _mock_starkEx_getOrderRoot(0);
        // And
        _mock_bridge_batch_getFee(dstChainIds_, 0, 1, nativeFees_, bridges_);
        // And
        _mock_bridge_batchKeep(dstChainIds_, 0, 1, nativeFees_, fees_, bridges_);
        // And
        vm.expectRevert(abi.encodeWithSelector(IMultiBridgeTransmitter.StaleUpdateError.selector, dstChainIds_[2], 1));

        // Act + Assert
        vm.deal(_keeper(), totalValue);
        vm.prank(_keeper());
        _transmitter.sendBatch{ value: totalValue }(dstChainIds_, payable(_keeper()));
    }

    function test_sendBatch_RefundError() public {
        // Arrange
        MockKeeper mockKeeper_ = new MockKeeper();
        // And
        uint256 totalValue = 9 ether;
        vm.deal(_keeper(), totalValue);
        // And
        address[] memory bridges_ = _transmitter.getBridges();
        // And
        uint16[] memory dstChainIds_ = new uint16[](3);
        dstChainIds_[0] = MOCK_CHAIN_ID;
        dstChainIds_[1] = MOCK_CHAIN_ID + 1;
        dstChainIds_[2] = MOCK_CHAIN_ID + 2;
        // And
        uint256[] memory nativeFees_ = new uint256[](3);
        nativeFees_[0] = 3 ether;
        nativeFees_[1] = 3 ether;
        nativeFees_[2] = 3 ether;
        // And
        uint256[] memory fees_ = new uint256[](3);
        fees_[0] = 3 ether / bridges_.length;
        fees_[1] = 3 ether / bridges_.length;
        fees_[2] = 3 ether / bridges_.length;
        // And
        _mock_starkEx_getSequenceNumber(1);
        // And
        _mock_starkEx_getOrderRoot(0);
        // And
        _mock_bridge_batch_getFee(dstChainIds_, 0, 1, nativeFees_, bridges_);
        // And
        _mock_bridge_batchKeep(dstChainIds_, 0, 1, nativeFees_, fees_, bridges_);
        // And
        vm.expectRevert(abi.encodeWithSelector(IMultiBridgeTransmitter.RefundError.selector));

        // Act + Assert
        vm.prank(_keeper());
        _transmitter.sendBatch{ value: totalValue }(dstChainIds_, payable(address(mockKeeper_)));
    }

    //==============================================================================//
    //=== calcTotalFee Tests                                                     ===//
    //==============================================================================//

    function test_calcTotalFee_ok(uint256 orderRoot_, uint256 sequenceNumber_) public {
        // Arrange
        _mock_starkEx_getOrderRoot(orderRoot_);
        // And
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        address[] memory bridges_ = _transmitter.getBridges();
        _mock_bridge_getFee(MOCK_CHAIN_ID, orderRoot_, sequenceNumber_, 3 ether, bridges_);

        // Act + Asset
        uint256 fee_ = _transmitter.calcTotalFee(MOCK_CHAIN_ID);
        assertEq(3 ether, fee_);
    }

    //==============================================================================//
    //=== addBridge Tests                                                        ===//
    //==============================================================================//

    function test_addBridge_ok() public {
        // Arrange
        address newBridge_ = vm.addr(10);
        // And
        vm.expectEmit(true, false, false, true, address(_transmitter));
        emit LogNewBridgeAdded(newBridge_);

        // Act
        vm.prank(_owner());
        _transmitter.addBridge(newBridge_);
    }

    function test_addBridge_BridgeAlreadyAddedError() public {
        // Arrange
        address newBridge_ = vm.addr(3);
        // And
        vm.expectRevert(abi.encodeWithSelector(IMultiBridgeTransmitter.BridgeAlreadyAddedError.selector));

        // Act
        vm.prank(_owner());
        _transmitter.addBridge(newBridge_);
    }

    function test_addBridge_onlyOwner() public {
        // Arrange
        address newBridge_ = vm.addr(10);
        // And
        vm.expectRevert("Ownable: caller is not the owner");

        // Act + Assert
        vm.prank(_intruder());
        _transmitter.addBridge(newBridge_);
    }

    //==============================================================================//
    //=== removeBridge Tests                                                     ===//
    //==============================================================================//

    function test_removeBridge_ok() public {
        // Arrange
        address oldBridge_ = vm.addr(5);
        // And
        vm.expectEmit(true, false, false, true, address(_transmitter));
        emit LogBridgeRemoved(oldBridge_);

        // Act
        vm.prank(_owner());
        _transmitter.removeBridge(oldBridge_);
    }

    function test_removeBridge_BridgeNotInListError() public {
        // Arrange
        address oldBridge_ = vm.addr(10);
        // And
        vm.expectRevert(abi.encodeWithSelector(IMultiBridgeTransmitter.BridgeNotInListError.selector));

        // Act
        vm.prank(_owner());
        _transmitter.removeBridge(oldBridge_);
    }

    function test_removeBridge_onlyOwner() public {
        // Arrange
        address oldBridge_ = vm.addr(5);
        // And
        vm.expectRevert("Ownable: caller is not the owner");

        // Act + Assert
        vm.prank(_intruder());
        _transmitter.removeBridge(oldBridge_);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _constructor(address owner_, address starkEx_) internal returns (address transmitter_) {
        // Arrange
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(address(0), owner_);
        vm.expectEmit(true, false, false, true);
        emit LogSetStarkExAddress(starkEx_);

        // Act
        vm.prank(owner_);
        transmitter_ = address(new MultiBridgeTransmitter(starkEx_));
    }

    function _setBridgeTransmitters(address owner_, address[] memory bridges_) internal {
        // Arrange
        for (uint256 i = 0; i < bridges_.length; i++) {
            vm.expectEmit(true, true, false, true, address(_transmitter));
            emit LogNewBridgeAdded(bridges_[i]);
        }

        // Act + Assert
        vm.startPrank(owner_);
        for (uint256 f = 0; f < bridges_.length; f++) {
            _transmitter.addBridge(bridges_[f]);
        }
        vm.stopPrank();
        assertEq(_transmitter.getBridges(), bridges_);
    }

    function _send(uint16 dstChainId_, uint256 sequenceNumber_, uint256 orderRoot_, uint256 nativeFee_) public {
        // Arrange
        address[] memory bridges_ = _transmitter.getBridges();
        // And
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        _mock_starkEx_getOrderRoot(orderRoot_);
        // And
        _mock_bridge_getFee(dstChainId_, orderRoot_, sequenceNumber_, nativeFee_, bridges_);
        // And
        _mock_bridge_keep(dstChainId_, orderRoot_, sequenceNumber_, nativeFee_, bridges_);
        // And
        for (uint256 i = 0; i < bridges_.length - 1; i++) {
            // -1 to have a transmit failed example
            vm.expectEmit(true, true, true, true, address(_transmitter));
            emit LogTransmitSuccess(bridges_[i], dstChainId_, sequenceNumber_, abi.encode(orderRoot_));
        }
        // And
        vm.expectEmit(true, true, true, true, address(_transmitter)); // transmit failed example
        emit LogTransmitFailed(bridges_[bridges_.length - 1], dstChainId_, sequenceNumber_, abi.encode(orderRoot_));

        // Act + Assert
        vm.prank(_keeper());
        _transmitter.send{ value: nativeFee_ }(dstChainId_, payable(_keeper()));
    }

    function _mock_starkEx_getSequenceNumber(uint256 returnedSequenceNumber_) internal {
        vm.mockCall(
            _starkEx,
            0,
            abi.encodeWithSelector(IStarkEx.getSequenceNumber.selector),
            abi.encode(returnedSequenceNumber_)
        );
    }

    function _mock_starkEx_getOrderRoot(uint256 returnedOrderRoot_) internal {
        vm.mockCall(_starkEx, 0, abi.encodeWithSelector(IStarkEx.getOrderRoot.selector), abi.encode(returnedOrderRoot_));
    }

    function _mock_bridge_getFee(
        uint16 dstChainId_,
        uint256 orderRoot_,
        uint256 sequenceNumber_,
        uint256 nativeFee_,
        address[] memory bridges_
    ) internal {
        for (uint256 i = 0; i < bridges_.length; i++) {
            vm.mockCall(
                bridges_[i],
                0,
                abi.encodeWithSelector(
                    IBridgeTransmitter.getFee.selector, dstChainId_, abi.encode(abi.encode(orderRoot_), sequenceNumber_)
                ),
                abi.encode(nativeFee_ / bridges_.length)
            );
        }
    }

    function _mock_bridge_batch_getFee(
        uint16[] memory dstChainIds_,
        uint256 orderRoot_,
        uint256 sequenceNumber_,
        uint256[] memory nativeFees_,
        address[] memory bridges_
    ) internal {
        for (uint256 i = 0; i < bridges_.length; i++) {
            for (uint256 f = 0; f < dstChainIds_.length; f++) {
                vm.mockCall(
                    bridges_[i],
                    0,
                    abi.encodeWithSelector(
                        IBridgeTransmitter.getFee.selector,
                        dstChainIds_[f],
                        abi.encode(abi.encode(orderRoot_), sequenceNumber_)
                    ),
                    abi.encode(nativeFees_[f] / bridges_.length)
                );
            }
        }
    }

    function _mock_bridge_keep(
        uint16 dstChainId_,
        uint256 orderRoot_,
        uint256 sequenceNumber_,
        uint256 nativeFee_,
        address[] memory bridges_
    ) internal {
        for (uint256 i = 0; i < bridges_.length - 1; i++) {
            // -1 to have a transmit failed example
            vm.mockCall(
                bridges_[i],
                nativeFee_ / bridges_.length,
                abi.encodeWithSelector(
                    IBridgeTransmitter.keep.selector,
                    dstChainId_,
                    payable(_keeper()),
                    abi.encode(abi.encode(orderRoot_), sequenceNumber_)
                ),
                bytes("")
            );
        }
    }

    function _mock_bridge_batchKeep(
        uint16[] memory dstChainIds_,
        uint256 orderRoot_,
        uint256 sequenceNumber_,
        uint256[] memory nativeFees_,
        uint256[] memory fees_,
        address[] memory bridges_
    ) internal {
        for (uint256 z = 0; z < bridges_.length - 1; z++) {
            // -1 to have a transmit failed example
            vm.mockCall(
                bridges_[z],
                nativeFees_[z],
                abi.encodeWithSelector(
                    IBridgeTransmitter.batchKeep.selector,
                    dstChainIds_,
                    fees_,
                    payable(_keeper()),
                    abi.encode(abi.encode(orderRoot_), sequenceNumber_)
                ),
                bytes("")
            );
        }
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
