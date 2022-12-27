//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Constants } from "src/constants/Constants.sol";
import { DepositFacet } from "src/facets/DepositFacet.sol";
import { IAccessControlFacet } from "src/interfaces/facets/IAccessControlFacet.sol";
import { IDepositFacet } from "src/interfaces/facets/IDepositFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { ITokenRegisterFacet } from "src/interfaces/facets/ITokenRegisterFacet.sol";
import { PatriciaTree } from "src/dependencies/mpt/v2/PatriciaTree.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

import { console2 as Console } from "@forge-std/console2.sol";

import { HelpersECDSA } from "src/helpers/HelpersECDSA.sol";

contract DepositFacetTest is BaseFixture {
    //==============================================================================//
    //=== Constants                                                              ===//
    //==============================================================================//

    uint256 internal constant STARK_KEY = 1234;

    /**
     * tokenId Sold:       0x3003a65651d3b9fb2eff934a4416db301afd112a8492aaf8d7297fc87dcd9f4
     * tokenId Fees:       70bf591713d7cb7150523cf64add8d49fa6b61036bba9f596bd2af8e3bb86f9
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

    uint256 internal constant USER_TOKENS = 10;

    //==============================================================================//
    //=== State Variables                                                        ===//
    //==============================================================================//

    MockERC20 token;

    //==============================================================================//
    //=== Events                                                                 ===//
    //==============================================================================//

    event LogLockDeposit(uint256 indexed lockHash, uint256 indexed starkKey, address indexed token, uint256 amount);
    event LogClaimDeposit(uint256 indexed lockHash, address indexed recipient);
    event LogReclaimDeposit(uint256 indexed lockHash);

    //==============================================================================//
    //=== Setup                                                                  ===//
    //==============================================================================//

    function setUp() public override {
        super.setUp();

        // Deploy token
        vm.prank(_tokenDeployer());
        token = (new MockERC20){salt: "USDC"}("USD Coin", "USDC", 6); // 0xa33e385d3ab4a55cc949115bb5cb57fb16143d4b
        
        // Mint token to user
        token.mint(_user(), USER_TOKENS);


        // Register token in bridge
        vm.prank(_tokenAdmin());
        ITokenRegisterFacet(bridge).setTokenRegister(address(token), true);
    }

    //==============================================================================//
    //=== initialize Tests                                                       ===//
    //==============================================================================//

    function test_deposit_initialize_ok() public {
        assertEq(IDepositFacet(bridge).getDepositExpirationTimeout(), Constants.DEPOSIT_ONCHAIN_EXPIRATION_TIMEOUT);
    }

    //==============================================================================//
    //=== depositExpirationTimeout Tests                                         ===//
    //==============================================================================//

    function test_set_depositExpirationTimeout_ok() public {
        // Arrange
        uint256 newTimeout = 500;

        // Act 
        vm.prank(_owner());
        IDepositFacet(bridge).setDepositExpirationTimeout(newTimeout);

        // Assert
        assertEq(IDepositFacet(bridge).getDepositExpirationTimeout(), newTimeout);
    }

    function test_set_depositExpirationTimeout_notRole() public {
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.Unauthorized.selector));
        IDepositFacet(bridge).setDepositExpirationTimeout(999);
    }

    //==============================================================================//
    //=== lockDeposit Tests                                                      ===//
    //==============================================================================//

    function test_lockDeposit_ok() public {
        _userApproveAndLockDepositAndValidate(_user(), STARK_KEY, address(token), USER_TOKENS, LOCK_HASH);
    }

    function test_lockDeposit_WhentokenNotRegistered_tokenNotRegisteredError() public {
        // Arrange
        address token_ = vm.addr(12345);

        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(LibTokenRegister.TokenNotRegisteredError.selector, token_));
        IDepositFacet(bridge).lockDeposit(STARK_KEY, token_, 888, LOCK_HASH);
    }

    function test_lockDeposit_WhenZeroStarkKey_InvalidStarkKeyError() public {
        // Arrange
        uint256 starkKey_ = 0;

        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.InvalidStarkKeyError.selector));
        IDepositFacet(bridge).lockDeposit(starkKey_, address(token), 888, LOCK_HASH);
    }

    function test_lockDeposit_WhenLargerThanModulusStarkKey_InvalidStarkKeyError() public {
        // Arrange
        uint256 starkKey_ = Constants.K_MODULUS;

        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.InvalidStarkKeyError.selector));
        IDepositFacet(bridge).lockDeposit(starkKey_, address(token), 888, LOCK_HASH);
    }

    function test_lockDeposit_WhenNotInCurveStarkKey_InvalidStarkKeyError() public {
        // Arrange
        uint256 starkKey_ = STARK_KEY - 1;

        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.InvalidStarkKeyError.selector));
        IDepositFacet(bridge).lockDeposit(starkKey_, address(token), 888, LOCK_HASH);
    }

    function test_lockDeposit_WhenZeroDepositAmount_InvalidDepositAmountError() public {
        // Arrange
        uint256 amount_ = 0;

        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.ZeroAmountError.selector));
        IDepositFacet(bridge).lockDeposit(STARK_KEY, address(token), amount_, LOCK_HASH);
    }

    function test_lockDeposit_WhenZeroLockHash_InvalidDepositLockError() public {
        // Arrange
        uint256 lockHash_ = 0;

        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.InvalidDepositLockError.selector));
        IDepositFacet(bridge).lockDeposit(STARK_KEY, address(token), 888, lockHash_);
    }

    function test_lockDeposit_WhenDepositAlreadyPending_DepositPendingError() public {
        // Arrange
        _userApproveAndLockDepositAndValidate(_user(), STARK_KEY, address(token), USER_TOKENS, LOCK_HASH);

        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositPendingError.selector));
        IDepositFacet(bridge).lockDeposit(STARK_KEY, address(token), USER_TOKENS, LOCK_HASH);
    }

    function test_lockDeposit_NotEnoughBalance() public {
        // Arrange
        uint256 amount_ = USER_TOKENS + 1;
        
        // Act 
        vm.prank(_user());
        token.approve(address(bridge), amount_);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(0x08c379a0, "ERC20: transfer amount exceeds balance"));
        vm.prank(_user());
        IDepositFacet(bridge).lockDeposit(STARK_KEY, address(token), amount_, LOCK_HASH);
    }

    //==============================================================================//
    //=== claimDeposit Tests                                                     ===//
    //==============================================================================//

    function test_claimDeposit_ok() public {
        // Arrange
        _userApproveAndLockDepositAndValidate(_user(), STARK_KEY, address(token), USER_TOKENS, LOCK_HASH);
        // And
        PatriciaTree mpt_ = new PatriciaTree();
        mpt_.insert(abi.encode(LOCK_HASH), abi.encode(1));
        (uint256 branchMask_, bytes32[] memory siblings_) = mpt_.getProof(abi.encode(LOCK_HASH));
        uint256 orderRoot_ = uint256(mpt_.root());
        // And
        vm.prank(_mockInteropContract());
        IStateFacet(bridge).setOrderRoot(orderRoot_);
        // And
        address recipient_ = vm.addr(777);
        vm.label(recipient_, "recipient");

        // Act + Assert
        vm.expectEmit(true, true, false, true);
        emit LogClaimDeposit(LOCK_HASH, recipient_);
        vm.prank(_operator());
        IDepositFacet(bridge).claimDeposit(LOCK_HASH, branchMask_, siblings_, recipient_);

        // Assert
        _validateDepositDeleted(LOCK_HASH);
        // And
        assertEq(MockERC20(address(token)).balanceOf(recipient_), USER_TOKENS);
    }

    function test_claimDeposit_zeroAddressRecipientError() public {
        // Arrange
        bytes32[] memory emptyArray; 

        // Act + Assert
        vm.prank(_operator());
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.ZeroAddressRecipientError.selector));
        IDepositFacet(bridge).claimDeposit(LOCK_HASH, 0, emptyArray, address(0));
    }

    function test_claimDeposit_depositNotFound() public {
        // Arrange
        bytes32[] memory emptyArray; 

        // Act + Assert
        vm.prank(_operator());
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositNotFoundError.selector));
        IDepositFacet(bridge).claimDeposit(LOCK_HASH, 0, emptyArray, vm.addr(777));
    }

    function test_claimDeposit_invalidLockHashError() public {
        // Arrange
        bytes32[] memory emptyArray; 

        // Act + Assert
        vm.prank(_operator());
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.InvalidDepositLockError.selector));
        IDepositFacet(bridge).claimDeposit(0, 0, emptyArray, vm.addr(777));
    }

    //==============================================================================//
    //=== reclaimDeposit Tests                                                   ===//
    //==============================================================================//

    function test_reclaimDeposit_ok() public {
        // Arrange
        _userApproveAndLockDepositAndValidate(_user(), STARK_KEY, address(token), USER_TOKENS, LOCK_HASH);
        // And
        vm.warp(block.timestamp + IDepositFacet(bridge).getDepositExpirationTimeout() + 1);

        // Act + Assert
        vm.expectEmit(true, false, false, true);
        emit LogReclaimDeposit(LOCK_HASH);
        vm.prank(_operator());
        IDepositFacet(bridge).reclaimDeposit(LOCK_HASH);
        
        // Assert
        _validateDepositDeleted(LOCK_HASH);
        // And
        assertEq(MockERC20(address(token)).balanceOf(_user()), USER_TOKENS);
    }

    function test_reclaimDeposit_depositNotExpiredError() public {
        // Arrange
        _userApproveAndLockDepositAndValidate(_user(), STARK_KEY, address(token), USER_TOKENS, LOCK_HASH);

        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositNotExpiredError.selector));
        IDepositFacet(bridge).reclaimDeposit(LOCK_HASH);
    }

    function test_reclaimDeposit_depositNotFound() public {
        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositNotFoundError.selector));
        IDepositFacet(bridge).reclaimDeposit(LOCK_HASH);
    }

    function test_reclaimDeposit_invalidLockHashError() public {
        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.InvalidDepositLockError.selector));
        IDepositFacet(bridge).reclaimDeposit(0);
    }

    //==============================================================================//
    //=== claimDeposit Tests                                                     ===//
    //==============================================================================//

    function test_getPendingDeposits() public {
        // Arrange
        _userApproveAndLockDepositAndValidate(_user(), STARK_KEY, address(token), USER_TOKENS, LOCK_HASH);

        // Act + Assert
        assertEq(IDepositFacet(bridge).getPendingDeposits(address(token)), USER_TOKENS);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _userApproveAndLockDepositAndValidate(
        address user_,
        uint256 starkKey_,
        address token_,
        uint256 amount_,
        uint256 lockHash_
    ) internal {
        // Act + Assert
        vm.startPrank(user_);
        token.approve(bridge, amount_);
        vm.expectEmit(true, true, true, true);
        emit LogLockDeposit(lockHash_, starkKey_, token_, amount_);
        IDepositFacet(bridge).lockDeposit(starkKey_, token_, amount_, lockHash_);
        vm.stopPrank();

        // Assert
        IDepositFacet.Deposit memory deposit_ = IDepositFacet(bridge).getDeposit(lockHash_);
        assertEq(deposit_.receiver, user_);
        assertEq(deposit_.starkKey, starkKey_);
        assertEq(deposit_.token, token_);
        assertEq(deposit_.amount, amount_);
        assertEq(deposit_.expirationDate, block.timestamp + IDepositFacet(bridge).getDepositExpirationTimeout());
    }

    function _validateDepositDeleted(uint256 lockHash_) internal {
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositNotFoundError.selector));
        IDepositFacet(bridge).getDeposit(lockHash_);
    }
}
