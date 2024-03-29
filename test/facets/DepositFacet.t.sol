//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { HelpersECDSA } from "src/helpers/HelpersECDSA.sol";

import { PatriciaTree } from "src/dependencies/mpt/v2/PatriciaTree.sol";

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
    mapping(bytes => bool) internal _storedKeys;
    PatriciaTree internal _mpt;

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
    //=== Helper Mappings                                                        ===//
    //==============================================================================//

    mapping(address => uint256) _initialBridgeBalances;
    mapping(address => uint256) _initialRecipientBalances;
    mapping(address => uint256) _initialPendingDeposits;
    mapping(address => uint256) _amountByToken;

    function setUp() public override {
        super.setUp();
        _mpt = new PatriciaTree();
    }

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
    //=== lockNativeDeposit Tests                                                   ===//
    //==============================================================================//

    function test_lockNativeDeposit_ok(uint256 starkKey_, uint256 amount_, uint256 lockHash_) public {
        vm.assume(starkKey_ < Constants.K_MODULUS && HelpersECDSA.isOnCurve(starkKey_));
        vm.assume(amount_ > 0);
        vm.assume(lockHash_ > 0);

        // Act + Assert
        // The lockNativeDeposit function is called in _lockDeposit when the given token is the NATIVE address.
        _lockDeposit(_user(), starkKey_, Constants.NATIVE, amount_, lockHash_);
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

    function test_claimDeposit_NATIVE_ok(uint256 amount_, uint256 lockHash_) public {
        vm.assume(amount_ > 0);
        vm.assume(lockHash_ > 0);

        // Act + Assert
        _lockDeposit(_user(), STARK_KEY, Constants.NATIVE, amount_, lockHash_);
        _claimDeposit(Constants.NATIVE, amount_, lockHash_, _recipient());
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
    //=== claimDeposit Tests                                                     ===//
    //==============================================================================//

    function test_claimDeposits_ok() public {
        // Arrange
        bytes[] memory keys_ = new bytes[](2);
        keys_[0] = hex"0123";
        keys_[1] = hex"0234";
        bytes[] memory amounts_ = new bytes[](keys_.length);
        amounts_[0] = abi.encode(1);
        amounts_[1] = abi.encode(1);
        address[] memory tokens_ = new address[](keys_.length);
        tokens_[0] = address(_token);
        tokens_[1] = Constants.NATIVE;

        // And
        _lockDeposit(_user(), STARK_KEY, tokens_[0], abi.decode(amounts_[0], (uint256)), uint256(keccak256(keys_[0])));
        _lockDeposit(_user(), STARK_KEY, tokens_[1], abi.decode(amounts_[1], (uint256)), uint256(keccak256(keys_[1])));

        // Act + Assert;
        _claimDeposits(tokens_, keys_, amounts_, _recipient());
    }

    /// @dev Gets ordered, non repeating keys.
    function test_claimDeposits_ok_SkipCI(bytes[] memory keys_) public {
        uint256[] memory uniqueIndices_ = new uint256[](keys_.length);
        uint256 uniqueIndicesLength_;
        // Arrange
        for (uint256 i_; i_ < keys_.length; i_++) {
            if (_storedKeys[keys_[i_]]) continue;
            _storedKeys[keys_[i_]] = true;

            uniqueIndices_[uniqueIndicesLength_++] = i_;
        }
        vm.assume(uniqueIndicesLength_ != 0);
        // And
        bytes[] memory uniqueKeys_ = new bytes[](uniqueIndicesLength_);
        bytes[] memory amounts_ = new bytes[](uniqueIndicesLength_);
        address[] memory tokens_ = new address[](uniqueIndicesLength_);
        for (uint256 i_; i_ < uniqueIndicesLength_; i_++) {
            uniqueKeys_[i_] = keys_[uniqueIndices_[i_]];
            amounts_[i_] = abi.encode(1);

            uint256 lockHash_ = uint256(keccak256(uniqueKeys_[i_]));
            tokens_[i_] = lockHash_ % 2 == 0 ? address(_token) : Constants.NATIVE;
            _lockDeposit(_user(), STARK_KEY, tokens_[i_], abi.decode(amounts_[i_], (uint256)), lockHash_);
        }

        // Act + Assert;
        _claimDeposits(tokens_, uniqueKeys_, amounts_, _recipient());
    }

    function test_claimDeposits_ZeroAddressRecipientError() public {
        // Arrange
        address recipient_;
        bytes32[] memory keys_;
        bytes32[] memory values_;
        bytes32[] memory proof_;
        uint8[] memory prefixesLengths_;

        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.ZeroAddressRecipientError.selector));

        // Act + Assert
        vm.prank(_operator());
        IDepositFacet(_bridge).claimDeposits(keys_, values_, proof_, prefixesLengths_, recipient_);
    }

    function test_claimDeposits_DepositNotFoundError() public {
        bytes[] memory keys_ = new bytes[](2);
        keys_[0] = hex"0123";
        keys_[1] = hex"0234";
        bytes[] memory values_ = new bytes[](keys_.length);
        values_[0] = hex"01";
        values_[1] = hex"01";

        // Arrange
        for (uint256 i_; i_ < keys_.length; i_++) {
            _mpt.insert(keys_[i_], values_[i_]);
        }
        // And
        (
            bytes32[] memory orderedKeys_,
            bytes32[] memory orderedValues_,
            uint8[] memory prefixesLengths_,
            bytes32[] memory siblings_
        ) = _mpt.getCompactProof(keys_);

        // And
        uint256 orderRoot_ = uint256(_mpt.root());
        vm.prank(_mockInteropContract());
        IStateFacet(_bridge).setOrderRoot(orderRoot_);

        // And
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositNotFoundError.selector));

        // Act + Assert
        vm.prank(_operator());
        IDepositFacet(_bridge).claimDeposits(orderedKeys_, orderedValues_, siblings_, prefixesLengths_, _recipient());
    }

    function test_claimDeposits_InvalidLockHashError() public {
        // Arrange
        bytes32[] memory keys_ = new bytes32[](1);
        bytes32[] memory values_ = new bytes32[](keys_.length);
        bytes32[] memory proof_;
        uint8[] memory prefixesLengths_;

        // And
        vm.expectRevert();

        // Act + Assert
        vm.prank(_operator());
        IDepositFacet(_bridge).claimDeposits(keys_, values_, proof_, prefixesLengths_, _recipient());
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

    function test_reclaimDeposit_NATIVE_ok(uint256 lockHash_) public {
        vm.assume(lockHash_ > 0);

        // Arrange
        _lockDeposit(_user(), STARK_KEY, Constants.NATIVE, USER_TOKENS, lockHash_);

        // Act + Assert
        _reclaimDeposit(_user(), Constants.NATIVE, USER_TOKENS, lockHash_);
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
        uint256 initialBridgeBalance_ = _getNativeOrERC20Balance(token_, _bridge);
        uint256 initialUserBalance_ = _getNativeOrERC20Balance(token_, user_);
        uint256 initialPendingDeposits_ = IDepositFacet(_bridge).getPendingDeposits(token_);

        // Act + Assert
        if (token_ != Constants.NATIVE) {
            vm.prank(user_);
            MockERC20(token_).approve(_bridge, amount_);
        }
        // And
        vm.expectEmit(true, true, true, true);
        emit LogLockDeposit(lockHash_, starkKey_, token_, amount_);
        // And
        vm.prank(user_);
        token_ != Constants.NATIVE
            ? IDepositFacet(_bridge).lockDeposit(starkKey_, token_, amount_, lockHash_)
            : IDepositFacet(_bridge).lockNativeDeposit{ value: amount_ }(starkKey_, lockHash_);

        // Assert
        IDepositFacet.Deposit memory deposit_ = IDepositFacet(_bridge).getDeposit(lockHash_);
        assertEq(deposit_.receiver, user_);
        assertEq(deposit_.starkKey, starkKey_);
        assertEq(deposit_.token, token_);
        assertEq(deposit_.amount, amount_);
        assertEq(deposit_.expirationDate, block.timestamp + IDepositFacet(_bridge).getDepositExpirationTimeout());
        // And
        assertEq(_getNativeOrERC20Balance(token_, _bridge), initialBridgeBalance_ + amount_);
        assertEq(_getNativeOrERC20Balance(token_, user_), initialUserBalance_ - amount_);
        assertEq(IDepositFacet(_bridge).getPendingDeposits(token_), initialPendingDeposits_ + amount_);
    }

    function _claimDeposit(address token_, uint256 amount_, uint256 lockHash_, address recipient_) internal {
        // Arrange
        uint256 initialBridgeBalance_ = _getNativeOrERC20Balance(token_, _bridge);
        uint256 initialRecipientBalance_ = _getNativeOrERC20Balance(token_, recipient_);
        uint256 initialPendingDeposits_ = IDepositFacet(_bridge).getPendingDeposits(token_);

        // And
        _mpt.insert(abi.encode(lockHash_), abi.encode(1));
        (uint256 branchMask_, bytes32[] memory siblings_) = _mpt.getProof(abi.encode(lockHash_));
        uint256 orderRoot_ = uint256(_mpt.root());
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
        assertEq(_getNativeOrERC20Balance(token_, _bridge), initialBridgeBalance_ - amount_);
        assertEq(_getNativeOrERC20Balance(token_, recipient_), initialRecipientBalance_ + amount_);
        assertEq(IDepositFacet(_bridge).getPendingDeposits(token_), initialPendingDeposits_ - amount_);
    }

    function _claimDeposits(
        address[] memory tokens_,
        bytes[] memory uniqueKeys_,
        bytes[] memory amounts_,
        address recipient_
    ) internal {
        // Arrange
        for (uint256 i_ = 0; i_ < tokens_.length; i_++) {
            _initialBridgeBalances[tokens_[i_]] = _getNativeOrERC20Balance(tokens_[i_], _bridge);
            _initialRecipientBalances[tokens_[i_]] = _getNativeOrERC20Balance(tokens_[i_], recipient_);
            _initialPendingDeposits[tokens_[i_]] = IDepositFacet(_bridge).getPendingDeposits(tokens_[i_]);
        }
        // And
        for (uint256 i_; i_ < uniqueKeys_.length; i_++) {
            _mpt.insert(uniqueKeys_[i_], amounts_[i_]);
        }
        // And
        (
            bytes32[] memory orderedKeys_,
            bytes32[] memory orderedValues_,
            uint8[] memory prefixesLengths_,
            bytes32[] memory siblings_
        ) = _mpt.getCompactProof(uniqueKeys_);

        // And
        uint256 root_ = uint256(_mpt.root());
        vm.prank(_mockInteropContract());
        IStateFacet(_bridge).setOrderRoot(root_);

        // Act + Assert
        for (uint256 i_ = 0; i_ < orderedKeys_.length; i_++) {
            vm.expectEmit(true, true, false, true);
            emit LogClaimDeposit(uint256(orderedKeys_[i_]), recipient_);
        }
        vm.prank(_operator());
        IDepositFacet(_bridge).claimDeposits(orderedKeys_, orderedValues_, siblings_, prefixesLengths_, recipient_);

        // Assert
        for (uint256 i_ = 0; i_ < orderedKeys_.length; i_++) {
            _validateDepositDeleted(uint256(orderedKeys_[i_]));
            _amountByToken[tokens_[i_]] += abi.decode(_mpt.getValue(uniqueKeys_[i_]), (uint256));
        }

        for (uint256 i_ = 0; i_ < tokens_.length; i_++) {
            assertEq(
                _getNativeOrERC20Balance(tokens_[i_], _bridge),
                _initialBridgeBalances[tokens_[i_]] - _amountByToken[tokens_[i_]]
            );
            assertEq(
                _getNativeOrERC20Balance(tokens_[i_], recipient_),
                _initialRecipientBalances[tokens_[i_]] + _amountByToken[tokens_[i_]]
            );
            assertEq(
                IDepositFacet(_bridge).getPendingDeposits(tokens_[i_]),
                _initialPendingDeposits[tokens_[i_]] - _amountByToken[tokens_[i_]]
            );
        }
    }

    function _reclaimDeposit(address user_, address token_, uint256 amount_, uint256 lockHash_) internal {
        // Arrange
        uint256 initialBridgeBalance_ = _getNativeOrERC20Balance(token_, _bridge);
        uint256 initialUserBalance_ = _getNativeOrERC20Balance(token_, user_);
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
        assertEq(_getNativeOrERC20Balance(token_, _bridge), initialBridgeBalance_ - amount_);
        assertEq(_getNativeOrERC20Balance(token_, user_), initialUserBalance_ + amount_);
        assertEq(IDepositFacet(_bridge).getPendingDeposits(token_), initialPendingDeposits_ - amount_);
    }

    function _validateDepositDeleted(uint256 lockHash_) internal {
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositNotFoundError.selector));
        IDepositFacet(_bridge).getDeposit(lockHash_);
    }
}
