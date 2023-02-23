// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TimelockController } from "@openzeppelin/governance/TimelockController.sol";
import { PatriciaTree } from "src/dependencies/mpt/v2/PatriciaTree.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { LzEndpointMock } from "test/mocks/lz/LzEndpointMock.sol";
import { HelpersECDSA } from "src/helpers/HelpersECDSA.sol";

import { MockERC20 } from "test/mocks/MockERC20.sol";
import { Constants } from "src/constants/Constants.sol";
import { LzFixture } from "test/fixtures/LzFixture.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { IDepositFacet } from "src/interfaces/facets/IDepositFacet.sol";
import { ILzReceptor } from "src/interfaces/interoperability/ILzReceptor.sol";
import { IStarkEx } from "src/interfaces/interoperability/IStarkEx.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

contract IntegrationTest is LzFixture {
    TimelockController private _timelock;

    //==============================================================================//
    //=== Events                                                                 ===//
    //==============================================================================//

    // Transmitter.
    event LogNewOrderRootSent(uint16 indexed dstChainId, uint256 indexed sequenceNumber, bytes indexed orderRoot);

    // Receptor.
    event LogRootReceived(uint256 indexed orderRoot);
    event LogOutdatedRootReceived(uint256 indexed orderRoot, uint64 indexed nonce);
    event LogOrderRootUpdate(uint256 indexed orderRoot);

    // DepositFacet.
    event LogLockDeposit(uint256 indexed lockHash, uint256 indexed starkKey, address indexed token, uint256 amount);
    event LogClaimDeposit(uint256 indexed lockHash, address indexed recipient);

    function test_TimeLockController() public {
        // Only owner can propose and cancel actions.
        address[] memory proposers_ = new address[](1);
        proposers_[0] = _owner();

        // Anyone can execute actions.
        address[] memory executors_ = new address[](1);
        executors_[0] = address(0);

        vm.startPrank(_owner());
        _timelock = new TimelockController(48 hours, proposers_, executors_, address(0));

        bytes memory acceptRoleCalldata_ =
            abi.encodeWithSelector(IAccessControlFacet.acceptRole.selector, LibAccessControl.OWNER_ROLE);

        // Set the timelock as the pending owner of the bridge.
        IAccessControlFacet(_bridge).setPendingRole(LibAccessControl.OWNER_ROLE, address(_timelock));

        // Schedule the timelock to accept the owner role.
        _timelock.schedule(_bridge, 0, acceptRoleCalldata_, 0, 0, 48 hours);

        // Advance the time by 48 hours.
        vm.warp(block.timestamp + 48 hours);

        // Execute the scheduled action.
        _timelock.execute(_bridge, 0, acceptRoleCalldata_, 0, 0);

        vm.stopPrank();

        // Check that the timelock is now the owner of the bridge.
        assertEq(IAccessControlFacet(_bridge).getRole(LibAccessControl.OWNER_ROLE), address(_timelock));
    }

    //==============================================================================//
    //=== deposit Tests                                                          ===//
    //==============================================================================//

    function test_deposit_and_claim(uint256 starkKey_, uint256 amount_, uint256 lockHash_) public {
        vm.assume(starkKey_ < Constants.K_MODULUS && HelpersECDSA.isOnCurve(starkKey_));
        vm.assume(amount_ > 0);
        vm.assume(lockHash_ > 0);

        _lockDeposit(MOCK_CHAIN_ID_SIDECHAIN_1, _user(), starkKey_, address(_token), amount_, lockHash_);
        _claimDeposit(MOCK_CHAIN_ID_SIDECHAIN_1, address(_token), amount_, lockHash_, _recipient());
    }

    //==============================================================================//
    //=== keep Tests                                                             ===//
    //==============================================================================//

    function test_full_keep_ok(uint256 orderRoot_, uint256 sequenceNumber_) public {
        vm.assume(sequenceNumber_ > 0);

        _keep_and_setRoot(MOCK_CHAIN_ID_SIDECHAIN_1, orderRoot_, sequenceNumber_);
        _keep_and_setRoot(MOCK_CHAIN_ID_SIDECHAIN_2, orderRoot_, sequenceNumber_);
    }

    //==============================================================================//
    //=== batchKeep Tests                                                        ===//
    //==============================================================================//

    function test_full_batchKeep_ok(uint256 orderRoot_, uint256 sequenceNumber_) public {
        vm.assume(sequenceNumber_ > 0);

        _batchKeep_and_setRoots(orderRoot_, sequenceNumber_);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _lockDeposit(
        uint16 chainId_,
        address user_,
        uint256 starkKey_,
        address token_,
        uint256 amount_,
        uint256 lockHash_
    ) internal {
        // Arrange
        (address bridge_,) = _getBridgeAndReceptorFromChainId(chainId_);
        // And
        uint256 initialUserBalance_ = MockERC20(token_).balanceOf(user_);
        uint256 initialPendingDeposits_ = IDepositFacet(_bridge).getPendingDeposits(token_);

        // Act + Assert
        vm.prank(user_);
        MockERC20(token_).approve(bridge_, amount_);
        // And
        vm.expectEmit(true, true, true, true);
        emit LogLockDeposit(lockHash_, starkKey_, token_, amount_);
        // And
        vm.prank(user_);
        IDepositFacet(bridge_).lockDeposit(starkKey_, token_, amount_, lockHash_);

        // Assert
        IDepositFacet.Deposit memory deposit_ = IDepositFacet(bridge_).getDeposit(lockHash_);
        assertEq(deposit_.receiver, user_);
        assertEq(deposit_.starkKey, starkKey_);
        assertEq(deposit_.token, token_);
        assertEq(deposit_.amount, amount_);
        assertEq(deposit_.expirationDate, block.timestamp + IDepositFacet(bridge_).getDepositExpirationTimeout());
        // And
        assertEq(MockERC20(token_).balanceOf(user_), initialUserBalance_ - amount_);
        assertEq(IDepositFacet(bridge_).getPendingDeposits(token_), initialPendingDeposits_ + amount_);
    }

    function _claimDeposit(uint16 chainId_, address token_, uint256 amount_, uint256 lockHash_, address recipient_)
        internal
    {
        // Arrange
        (address bridge_,) = _getBridgeAndReceptorFromChainId(chainId_);
        // And
        uint256 initialPendingDeposits_ = IDepositFacet(bridge_).getPendingDeposits(token_);
        uint256 initialRecipientBalance_ = MockERC20(token_).balanceOf(recipient_);
        // And
        PatriciaTree mpt_ = new PatriciaTree();
        mpt_.insert(abi.encode(lockHash_), abi.encode(1));
        (uint256 branchMask_, bytes32[] memory siblings_) = mpt_.getProof(abi.encode(lockHash_));
        uint256 orderRoot_ = uint256(mpt_.root());
        // And
        _keep_and_setRoot(chainId_, orderRoot_, 1);

        // Act + Assert
        vm.expectEmit(true, true, false, true);
        emit LogClaimDeposit(lockHash_, recipient_);
        vm.prank(_operator());
        IDepositFacet(bridge_).claimDeposit(lockHash_, branchMask_, siblings_, recipient_);

        // Assert
        _validateDepositDeleted(lockHash_);
        // And
        assertEq(MockERC20(token_).balanceOf(recipient_), initialRecipientBalance_ + amount_);
        assertEq(IDepositFacet(bridge_).getPendingDeposits(token_), initialPendingDeposits_ - amount_);
    }

    function _keep_and_setRoot(uint16 chainId_, uint256 orderRoot_, uint256 sequenceNumber_) private {
        // Arrange
        vm.deal(_keeper(), 100 ether);
        // And
        (address bridge_, ILzReceptor receptor_) = _getBridgeAndReceptorFromChainId(chainId_);
        // And
        _mock_starkEx_getOrderRoot(orderRoot_);
        // And
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        vm.expectEmit(true, false, false, true, address(receptor_));
        emit LogRootReceived(orderRoot_);
        // And
        vm.expectEmit(true, true, true, true, address(_transmitter));
        emit LogNewOrderRootSent(chainId_, sequenceNumber_, abi.encode(orderRoot_));

        // Act + Assert
        vm.prank(_keeper());
        _transmitter.keep{ value: 1 ether }(chainId_, payable(_keeper()));

        _setOrderRoot(bridge_, address(receptor_), orderRoot_);
    }

    function _batchKeep_and_setRoots(uint256 orderRoot_, uint256 sequenceNumber_) private {
        // Arrange
        vm.deal(_keeper(), 100 ether);
        // And
        _mock_starkEx_getOrderRoot(orderRoot_);
        // And
        _mock_starkEx_getSequenceNumber(sequenceNumber_);
        // And
        vm.expectEmit(true, false, false, true, address(_receptorSideChain1));
        emit LogRootReceived(orderRoot_);
        // And
        vm.expectEmit(true, true, true, true, address(_transmitter));
        emit LogNewOrderRootSent(MOCK_CHAIN_ID_SIDECHAIN_1, sequenceNumber_, abi.encode(orderRoot_));
        // And
        vm.expectEmit(true, false, false, true, address(_receptorSideChain2));
        emit LogRootReceived(orderRoot_);
        // And
        vm.expectEmit(true, true, true, true, address(_transmitter));
        emit LogNewOrderRootSent(MOCK_CHAIN_ID_SIDECHAIN_2, sequenceNumber_, abi.encode(orderRoot_));
        // And
        uint16[] memory dstChainIds_ = new uint16[](2);
        dstChainIds_[0] = MOCK_CHAIN_ID_SIDECHAIN_1;
        dstChainIds_[1] = MOCK_CHAIN_ID_SIDECHAIN_2;
        // And
        uint256[] memory nativeFees_ = new uint256[](2);
        nativeFees_[0] = 0.2 ether;
        nativeFees_[1] = 0.3 ether;

        // Act + Assert
        vm.prank(_keeper());
        _transmitter.batchKeep{ value: 0.5 ether }(dstChainIds_, nativeFees_, payable(_keeper()));

        // Assert
        _setOrderRoot(_bridgeSideChain1, address(_receptorSideChain1), orderRoot_);
        _setOrderRoot(_bridgeSideChain2, address(_receptorSideChain2), orderRoot_);
    }

    function _setOrderRoot(address bridge_, address receptor_, uint256 orderRoot_) internal {
        assertEq(IStateFacet(bridge_).getOrderRoot(), 0);
        // Arrange
        vm.expectEmit(true, false, false, true, receptor_);
        emit LogOrderRootUpdate(orderRoot_);
        // Act
        vm.prank(_owner());
        ILzReceptor(receptor_).setOrderRoot();
        // Assert
        assertEq(IStateFacet(bridge_).getOrderRoot(), orderRoot_);
    }

    function _mock_starkEx_getOrderRoot(uint256 orderRoot_) internal {
        vm.mockCall(STARKEX_ADDRESS, abi.encodeWithSelector(IStarkEx.getOrderRoot.selector), abi.encode(orderRoot_));
    }

    function _mock_starkEx_getSequenceNumber(uint256 sequenceNumber_) internal {
        vm.mockCall(
            STARKEX_ADDRESS, abi.encodeWithSelector(IStarkEx.getSequenceNumber.selector), abi.encode(sequenceNumber_)
        );
    }

    function _getBridgeAndReceptorFromChainId(uint16 chainId_)
        internal
        view
        returns (address bridge_, ILzReceptor receptor_)
    {
        if (chainId_ == MOCK_CHAIN_ID_SIDECHAIN_1) {
            bridge_ = _bridgeSideChain1;
            receptor_ = _receptorSideChain1;
        } else if (chainId_ == MOCK_CHAIN_ID_SIDECHAIN_2) {
            bridge_ = _bridgeSideChain2;
            receptor_ = _receptorSideChain2;
        } else {
            revert("Invalid chain id");
        }
    }

    function _validateDepositDeleted(uint256 lockHash_) internal {
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositNotFoundError.selector));
        IDepositFacet(_bridge).getDeposit(lockHash_);
    }
}
