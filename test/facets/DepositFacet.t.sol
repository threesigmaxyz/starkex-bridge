//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { PatriciaTree } from "src/dependencies/mpt/v2/PatriciaTree.sol";
import { HelpersECDSA } from "src/helpers/HelpersECDSA.sol";

import { Constants } from "src/constants/Constants.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { IDepositFacet } from "src/interfaces/facets/IDepositFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";

contract DepositFacetTest is BaseFixture {
    //==============================================================================//
    //=== Constants                                                              ===//
    //==============================================================================//

    uint256 internal constant STARK_KEY = 1234;
    bytes32[] internal EMPTY_ARRAY;

    /**
     * _tokenId Sold:       0x3003a65651d3b9fb2eff934a4416db301afd112a8492aaf8d7297fc87dcd9f4
     * _tokenId Fees:       70bf591713d7cb7150523cf64add8d49fa6b61036bba9f596bd2af8e3bb86f9
     * Receiver Stark Key: 5fa3383597691ea9d827a79e1a4f0f7949435ced18ca9619de8ab97e661020
     * VaultId Sender:     34
     * VaultId Receiver:   21
     * VaultId Fees:       593128169
     * Nonce:              1
     * Quantized Amount:   2154549703648910716
     * Quantized Fee Max:  7
     * Expiration:         1580230800
     */
    uint256 internal constant LOCK_HASH =
        2_356_286_878_056_985_831_279_161_846_178_161_693_107_336_866_674_377_330_568_734_796_240_516_368_603;

    //==============================================================================//
    //=== Events                                                                 ===//
    //==============================================================================//

    event LogSetDepositExpirationTimeout(uint256 indexed timeout);
    event LogLockDeposit(uint256 indexed lockHash, uint256 indexed starkKey, address indexed token, uint256 amount);
    event LogClaimDeposit(uint256 indexed lockHash, address indexed recipient);
    event LogReclaimDeposit(uint256 indexed lockHash);

    //==============================================================================//
    //=== initialize Tests                                                       ===//
    //==============================================================================//

    function test_deposit_initialize_ok() public {
        assertEq(IDepositFacet(_bridge).getDepositExpirationTimeout(), Constants.DEPOSIT_ONCHAIN_EXPIRATION_TIMEOUT);
        assertEq(IDepositFacet(_bridge).getPendingDeposits(address(_token)), 0);
    }

    //==============================================================================//
    //=== depositExpirationTimeout Tests                                         ===//
    //==============================================================================//

    function test_setDepositExpirationTimeout_ok(uint256 timeout_) public {
        // Arrange
        vm.expectEmit(true, false, false, true, _bridge);
        emit LogSetDepositExpirationTimeout(timeout_);

        // Act
        vm.prank(_owner());
        IDepositFacet(_bridge).setDepositExpirationTimeout(timeout_);

        // Assert
        assertEq(IDepositFacet(_bridge).getDepositExpirationTimeout(), timeout_);
    }

    function test_setDepositExpirationTimeout_UnauthorizedError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.UnauthorizedError.selector));

        // Act + Assert
        vm.prank(_intruder());
        IDepositFacet(_bridge).setDepositExpirationTimeout(999);
    }

    //==============================================================================//
    //=== lockDeposit Tests                                                      ===//
    //==============================================================================//

    function test_lockDeposit_ERC20_ok(uint256 starkKey_, uint256 amount_, uint256 lockHash_) public {
        vm.assume(starkKey_ < Constants.K_MODULUS && HelpersECDSA.isOnCurve(starkKey_));
        vm.assume(amount_ > 0);
        vm.assume(lockHash_ > 0);

        // Act + Assert
        _lockDeposit(_user(), starkKey_, address(_token), amount_, lockHash_);
    }

    function test_lockDeposit_TokenNotRegisteredError() public {
        // Arrange
        address token_ = vm.addr(1);
        vm.label(token_, "token");
        vm.expectRevert(abi.encodeWithSelector(LibTokenRegister.TokenNotRegisteredError.selector, token_));

        // Act + Assert
        IDepositFacet(_bridge).lockDeposit(STARK_KEY, token_, USER_TOKENS, LOCK_HASH);
    }

    function test_lockDeposit_whenZeroStarkKey_InvalidStarkKeyError() public {
        // Arrange
        uint256 starkKey_ = 0;
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.InvalidStarkKeyError.selector));

        // Act + Assert
        IDepositFacet(_bridge).lockDeposit(starkKey_, address(_token), USER_TOKENS, LOCK_HASH);
    }

    function test_lockDeposit_whenLargerThanModulusStarkKey_InvalidStarkKeyError(uint256 starkKey_) public {
        vm.assume(starkKey_ >= Constants.K_MODULUS);

        // Arrange
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.InvalidStarkKeyError.selector));

        // Act + Assert
        IDepositFacet(_bridge).lockDeposit(starkKey_, address(_token), USER_TOKENS, LOCK_HASH);
    }

    function test_lockDeposit_whenNotInCurveStarkKey_InvalidStarkKeyError(uint256 starkKey_) public {
        vm.assume(HelpersECDSA.isOnCurve(starkKey_) == false);

        // Arrange
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.InvalidStarkKeyError.selector));

        // Act + Assert
        IDepositFacet(_bridge).lockDeposit(starkKey_, address(_token), USER_TOKENS, LOCK_HASH);
    }

    function test_lockDeposit_whenZeroDepositAmount_InvalidDepositAmountError() public {
        // Arrange
        uint256 amount_ = 0;
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.ZeroAmountError.selector));

        // Act + Assert
        IDepositFacet(_bridge).lockDeposit(STARK_KEY, address(_token), amount_, LOCK_HASH);
    }

    function test_lockDeposit_whenZeroLockHash_InvalidDepositLockError() public {
        // Arrange
        uint256 lockHash_ = 0;
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.InvalidDepositLockError.selector));

        // Act + Assert
        IDepositFacet(_bridge).lockDeposit(STARK_KEY, address(_token), USER_TOKENS, lockHash_);
    }

    function test_lockDeposit_DepositPendingError(uint256 lockHash_) public {
        vm.assume(lockHash_ > 0);

        // Arrange
        _lockDeposit(_user(), STARK_KEY, address(_token), USER_TOKENS, lockHash_);
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositPendingError.selector));

        // Act + Assert
        IDepositFacet(_bridge).lockDeposit(STARK_KEY, address(_token), USER_TOKENS, lockHash_);
    }

    function test_lockDeposit_HelpersErc20TransferFromError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(0x08c379a0, "ERC20: insufficient allowance"));

        // Act + Assert
        vm.prank(_user());
        IDepositFacet(_bridge).lockDeposit(STARK_KEY, address(_token), USER_TOKENS, LOCK_HASH);
    }

    //==============================================================================//
    //=== lockEthDeposit Tests                                                   ===//
    //==============================================================================//

    function test_lockEthDeposit_ok(uint256 starkKey_, uint256 amount_, uint256 lockHash_) public {
        vm.assume(starkKey_ < Constants.K_MODULUS && HelpersECDSA.isOnCurve(starkKey_));
        vm.assume(amount_ > 0);
        vm.assume(lockHash_ > 0);

        // Act + Assert
        // The lockEthDeposit function is called in _lockDeposit when the given token is the ETH address.
        _lockDeposit(_user(), starkKey_, Constants.ETH, amount_, lockHash_);
    }

    //==============================================================================//
    //=== claimDeposit Tests                                                     ===//
    //==============================================================================//

    function test_claimDeposit_ERC20_ok(uint256 amount_, uint256 lockHash_) public {
        vm.assume(amount_ > 0);
        vm.assume(lockHash_ > 0);

        // Act + Assert
        _lockDeposit(_user(), STARK_KEY, address(_token), amount_, lockHash_);
        _claimDeposit(address(_token), amount_, lockHash_, _recipient());
    }

    function test_claimDeposit_ETH_ok(uint256 amount_, uint256 lockHash_) public {
        vm.assume(amount_ > 0);
        vm.assume(lockHash_ > 0);

        // Act + Assert
        _lockDeposit(_user(), STARK_KEY, Constants.ETH, amount_, lockHash_);
        _claimDeposit(Constants.ETH, amount_, lockHash_, _recipient());
    }

    function test_claimDeposit_ZeroAddressRecipientError() public {
        // Arrange
        address recipient_ = address(0);
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.ZeroAddressRecipientError.selector));

        // Act + Assert
        vm.prank(_operator());
        IDepositFacet(_bridge).claimDeposit(LOCK_HASH, 0, EMPTY_ARRAY, recipient_);
    }

    function test_claimDeposit_DepositNotFoundError(uint256 lockHash_) public {
        vm.assume(lockHash_ > 0);

        // Arrange
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositNotFoundError.selector));

        // Act + Assert
        vm.prank(_operator());
        IDepositFacet(_bridge).claimDeposit(lockHash_, USER_TOKENS, EMPTY_ARRAY, _recipient());
    }

    function test_claimDeposit_InvalidLockHashError() public {
        // Arrange
        uint256 lockHash_ = 0;
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.InvalidDepositLockError.selector));

        // Act + Assert
        vm.prank(_operator());
        IDepositFacet(_bridge).claimDeposit(lockHash_, 0, EMPTY_ARRAY, _recipient());
    }

    //==============================================================================//
    //=== reclaimDeposit Tests                                                   ===//
    //==============================================================================//

    function test_reclaimDeposit_ERC20_ok(uint256 lockHash_) public {
        vm.assume(lockHash_ > 0);

        // Arrange
        _lockDeposit(_user(), STARK_KEY, address(_token), USER_TOKENS, lockHash_);

        // Act + Assert
        _reclaimDeposit(_user(), address(_token), USER_TOKENS, lockHash_);
    }

    function test_reclaimDeposit_ETH_ok(uint256 lockHash_) public {
        vm.assume(lockHash_ > 0);

        // Arrange
        _lockDeposit(_user(), STARK_KEY, Constants.ETH, USER_TOKENS, lockHash_);

        // Act + Assert
        _reclaimDeposit(_user(), Constants.ETH, USER_TOKENS, lockHash_);
    }

    function test_reclaimDeposit_depositNotExpiredError(uint256 timePassed_) public {
        vm.assume(timePassed_ <= block.timestamp + IDepositFacet(_bridge).getDepositExpirationTimeout());

        // Arrange
        _lockDeposit(_user(), STARK_KEY, address(_token), USER_TOKENS, LOCK_HASH);
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositNotExpiredError.selector));

        // Act + Assert
        vm.warp(timePassed_);
        IDepositFacet(_bridge).reclaimDeposit(LOCK_HASH);
    }

    function test_reclaimDeposit_depositNotFound(uint256 lockHash_) public {
        vm.assume(lockHash_ > 0);

        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositNotFoundError.selector));
        IDepositFacet(_bridge).reclaimDeposit(lockHash_);
    }

    function test_reclaimDeposit_invalidLockHashError() public {
        // Arrange
        uint256 lockHash_ = 0;

        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.InvalidDepositLockError.selector));
        IDepositFacet(_bridge).reclaimDeposit(lockHash_);
    }

    //==============================================================================//
    //=== getPendingDeposits Tests                                               ===//
    //==============================================================================//

    function test_getPendingDeposits_ok(uint256 amount1_, uint256 amount2_) public {
        vm.assume(amount1_ > 0);
        vm.assume(amount2_ > 0 && amount2_ <= type(uint256).max - amount1_);

        // Arrange + Act
        _lockDeposit(_user(), STARK_KEY, address(_token), amount1_, LOCK_HASH);
        // And
        _lockDeposit(_user(), STARK_KEY, address(_token), amount2_, LOCK_HASH + 1);

        // And
        _reclaimDeposit(_user(), address(_token), amount1_, LOCK_HASH);
        // And
        _reclaimDeposit(_user(), address(_token), amount2_, LOCK_HASH + 1);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _lockDeposit(address user_, uint256 starkKey_, address token_, uint256 amount_, uint256 lockHash_)
        internal
    {
        uint256 initialBridgeBalance_ = _getEthOrERC20Balance(token_, _bridge);
        uint256 initialUserBalance_ = _getEthOrERC20Balance(token_, user_);
        uint256 initialPendingDeposits_ = IDepositFacet(_bridge).getPendingDeposits(token_);
        
        // Act + Assert
        if (token_ != Constants.ETH) {
            vm.prank(user_);
            MockERC20(token_).approve(_bridge, amount_);
        }
        // And
        vm.expectEmit(true, true, true, true);
        emit LogLockDeposit(lockHash_, starkKey_, token_, amount_);
        // And
        vm.prank(user_);
        token_ != Constants.ETH 
            ? IDepositFacet(_bridge).lockDeposit(starkKey_, token_, amount_, lockHash_)
            : IDepositFacet(_bridge).lockEthDeposit{value: amount_}(starkKey_, lockHash_);

        // Assert
        IDepositFacet.Deposit memory deposit_ = IDepositFacet(_bridge).getDeposit(lockHash_);
        assertEq(deposit_.receiver, user_);
        assertEq(deposit_.starkKey, starkKey_);
        assertEq(deposit_.token, token_);
        assertEq(deposit_.amount, amount_);
        assertEq(deposit_.expirationDate, block.timestamp + IDepositFacet(_bridge).getDepositExpirationTimeout());
        // And
        assertEq(_getEthOrERC20Balance(token_, _bridge), initialBridgeBalance_ + amount_);
        assertEq(_getEthOrERC20Balance(token_, user_), initialUserBalance_ - amount_);
        assertEq(IDepositFacet(_bridge).getPendingDeposits(token_), initialPendingDeposits_ + amount_);
    }

    function _claimDeposit(address token_, uint256 amount_, uint256 lockHash_, address recipient_) internal {
        // Arrange
        uint256 initialBridgeBalance_ = _getEthOrERC20Balance(token_, _bridge);
        uint256 initialRecipientBalance_ = _getEthOrERC20Balance(token_, recipient_);
        uint256 initialPendingDeposits_ = IDepositFacet(_bridge).getPendingDeposits(token_);

        // And
        PatriciaTree mpt_ = new PatriciaTree();
        mpt_.insert(abi.encode(lockHash_), abi.encode(1));
        (uint256 branchMask_, bytes32[] memory siblings_) = mpt_.getProof(abi.encode(lockHash_));
        uint256 orderRoot_ = uint256(mpt_.root());
        // And
        vm.prank(_mockInteropContract());
        IStateFacet(_bridge).setOrderRoot(orderRoot_);

        // Act + Assert
        vm.expectEmit(true, true, false, true);
        emit LogClaimDeposit(lockHash_, recipient_);
        vm.prank(_operator());
        IDepositFacet(_bridge).claimDeposit(lockHash_, branchMask_, siblings_, recipient_);

        // Assert
        _validateDepositDeleted(lockHash_);
        // And
        assertEq(_getEthOrERC20Balance(token_, _bridge), initialBridgeBalance_ - amount_);
        assertEq(_getEthOrERC20Balance(token_, recipient_), initialRecipientBalance_ + amount_);
        assertEq(IDepositFacet(_bridge).getPendingDeposits(token_), initialPendingDeposits_ - amount_);
    }

    function _reclaimDeposit(address user_, address token_, uint256 amount_, uint256 lockHash_) internal {
        // Arrange
        uint256 initialBridgeBalance_ = _getEthOrERC20Balance(token_, _bridge);
        uint256 initialUserBalance_ = _getEthOrERC20Balance(token_, user_);
        uint256 initialPendingDeposits_ = IDepositFacet(_bridge).getPendingDeposits(token_);
        // And
        vm.warp(block.timestamp + IDepositFacet(_bridge).getDepositExpirationTimeout() + 1);

        // Act + Assert
        vm.expectEmit(true, false, false, true);
        emit LogReclaimDeposit(lockHash_);
        vm.prank(_operator());
        IDepositFacet(_bridge).reclaimDeposit(lockHash_);

        // Assert
        _validateDepositDeleted(lockHash_);
        assertEq(_getEthOrERC20Balance(token_, _bridge), initialBridgeBalance_ - amount_);
        assertEq(_getEthOrERC20Balance(token_, user_), initialUserBalance_ + amount_);
        assertEq(IDepositFacet(_bridge).getPendingDeposits(token_), initialPendingDeposits_ - amount_);
    }

    function _validateDepositDeleted(uint256 lockHash_) internal {
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositNotFoundError.selector));
        IDepositFacet(_bridge).getDeposit(lockHash_);
    }
}
