//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/interfaces/IERC20.sol";

import { Constants } from "src/constants/Constants.sol";
import { WithdrawalFacet } from "src/facets/WithdrawalFacet.sol";
import { ECDSA } from "src/dependencies/ecdsa/ECDSA.sol";
import { LibDiamond } from "src/libraries/LibDiamond.sol";
import { ITokenRegisterFacet } from "src/interfaces/facets/ITokenRegisterFacet.sol";
import { IWithdrawalFacet } from "src/interfaces/facets/IWithdrawalFacet.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

import { console2 as Console } from "@forge-std/console2.sol";

contract WithdrawalFacetTest is BaseFixture {
    //==============================================================================//
    //=== Constants                                                              ===//
    //==============================================================================//

    uint256 internal constant STARK_KEY =
        130_079_954_696_431_488_834_386_892_570_532_580_289_305_809_527_482_364_871_420_853_057_975_493_689;
    uint256 internal constant STARK_KEY_Y =
        2_014_815_737_900_971_088_087_974_256_122_814_428_168_792_651_933_467_019_210_567_933_592_263_251_564;

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

    uint256 internal SIGNATURE_R =
        595_786_754_653_736_406_426_889_615_487_225_077_940_077_177_382_942_628_692_506_542_715_327_069_361;
    uint256 internal SIGNATURE_S =
        1_089_493_324_092_646_311_927_517_238_061_643_471_633_017_553_425_201_144_689_187_441_352_003_681_763;

    // R: 151340ef2d746eeba6e124262b50e52f0ceaedf4395c05e511fe671eb71bcb1
    // S: 268a1a1637989d491e88a95cba4d717b24d77a6a8473eef30746c2c3189fde3

    // X: ab0f8bcc2f64bdbe189004ea19c438a1163bf186e8818572d99f01e2846533d
    // Y: 068d3f3018870efc22178a84034bc81b6e1b2d100ccce1f7a327ee6e8e3ec87
    // Z: 6f1bc22178a84034bc81b6e1b2d100ccce1f7a327ee6e8e3ec876f1bc22178a840

    //==============================================================================//
    //=== Events                                                                 ===//
    //==============================================================================//

    event LogLockWithdrawal(uint256 indexed lockHash, uint256 indexed starkKey, address indexed token, uint256 amount);
    event LogClaimWithdrawal(uint256 indexed lockHash, address indexed receiver);
    event LogReclaimWithdrawal(uint256 indexed lockHash, address indexed receiver);

    //==============================================================================//
    //=== State Variables                                                        ===//
    //==============================================================================//

    MockERC20 _token;

    //==============================================================================//
    //=== Setup                                                                  ===//
    //==============================================================================//

    function setUp() public override {
        super.setUp();

        // Deploy _token
        vm.prank(_tokenDeployer());
        _token = (new MockERC20){salt: "USDC"}("USD Coin", "USDC", 6); // 0xa33e385d3ab4a55cc949115bb5cb57fb16143d4b

        // Register _token in _bridge
        vm.prank(_tokenAdmin());
        ITokenRegisterFacet(_bridge).setTokenRegister(address(_token), true);

        // Mint USDC to _bridge
        _token.mint(address(_bridge), 1_000_000e6);
    }

    //==============================================================================//
    //=== initialize Tests                                                       ===//
    //==============================================================================//

    function test_withdrawal_initialize_ok() public {
        assertEq(
            IWithdrawalFacet(_bridge).getWithdrawalExpirationTimeout(), Constants.WITHDRAWAL_ONCHAIN_EXPIRATION_TIMEOUT
        );
         assertEq(IWithdrawalFacet(_bridge).getPendingWithdrawals(address(_token)), 0);
    }

    //==============================================================================//
    //=== setWithdrawalExpirationTimeout Tests                                                       ===//
    //==============================================================================//

    function test_setWithdrawalExpirationTimeout_ok() public {
        uint256 newTimeout = 500;
        vm.prank(_owner());
        IWithdrawalFacet(_bridge).setWithdrawalExpirationTimeout(newTimeout);
        assertEq(IWithdrawalFacet(_bridge).getWithdrawalExpirationTimeout(), newTimeout);
    }

    function test_setWithdrawalExpirationTimeout_unauthorizedError() public {
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.UnauthorizedError.selector));
        IWithdrawalFacet(_bridge).setWithdrawalExpirationTimeout(999);
    }

    //==============================================================================//
    //=== lockWithdrawal Tests                                                   ===//
    //==============================================================================//

    function test_lockWithdrawal_ok() public {
        _lockWithdrawal(STARK_KEY, address(_token), USER_TOKENS, LOCK_HASH);
    }

    function test_lockWithdrawal_InvalidLockHashError() public {
        vm.expectRevert(IWithdrawalFacet.InvalidLockHashError.selector);
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).lockWithdrawal(STARK_KEY, address(_token), USER_TOKENS, 0);
    }

    function test_lockWithdrawal_WhenZeroStarkKey_InvalidStarkKeyError() public {
        vm.expectRevert(IWithdrawalFacet.InvalidStarkKeyError.selector);
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).lockWithdrawal(0, address(_token), USER_TOKENS, LOCK_HASH);
    }

    function test_lockWithdrawal_WhenLargerThanModulusStarkKey_InvalidStarkKeyError(uint256 starkKey_) public {
        // Arrange
        vm.assume(starkKey_ >= Constants.K_MODULUS);
        
        // Act + Assert
        vm.expectRevert(IWithdrawalFacet.InvalidStarkKeyError.selector);
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).lockWithdrawal(starkKey_, address(_token), USER_TOKENS, LOCK_HASH);
    }

    function test_lockWithdrawal_WhenNotInCurveStarkKey_InvalidStarkKeyError() public {
        vm.expectRevert(IWithdrawalFacet.InvalidStarkKeyError.selector);
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).lockWithdrawal(STARK_KEY - 1, address(_token), USER_TOKENS, LOCK_HASH);
    }

    function test_lockWithdrawal_ZeroAmountError() public {
        vm.expectRevert(IWithdrawalFacet.ZeroAmountError.selector);
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).lockWithdrawal(STARK_KEY, address(_token), 0, LOCK_HASH);
    }

    //==============================================================================//
    //=== claimWithdrawal Tests                                                  ===//
    //==============================================================================//

    function test_claimWithdrawal_ok() public {
        // Arrange
        _lockWithdrawal(STARK_KEY, address(_token), USER_TOKENS, LOCK_HASH);
        // And
        bytes memory signature_ = abi.encode(SIGNATURE_R, SIGNATURE_S, STARK_KEY_Y);

        // Act + Assert
        _claimWithdrawal(LOCK_HASH, signature_, _recipient(), USER_TOKENS);
    }

    function test_claimWithdrawal_InvalidLockHashError() public {
        // Act + Assert
        vm.expectRevert(IWithdrawalFacet.InvalidLockHashError.selector);
        IWithdrawalFacet(_bridge).claimWithdrawal(0, abi.encode(0, 0, 0), vm.addr(123));
    }

    function test_claimWithdrawal_ZeroAddressRecipientError() public {
        // Act + Assert
        vm.expectRevert(IWithdrawalFacet.ZeroAddressRecipientError.selector);
        IWithdrawalFacet(_bridge).claimWithdrawal(LOCK_HASH, abi.encode(0, 0, 0), address(0));
    }

    function test_claimWithdrawal_WithdrawalNotFoundError() public {
        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(IWithdrawalFacet.WithdrawalNotFoundError.selector));
        IWithdrawalFacet(_bridge).claimWithdrawal(LOCK_HASH, abi.encode(1, 2, 3), vm.addr(1234));
    }

    function test_claimWithdrawal_InvalidStarkKeyYError(uint256 starkKeyY_) public {
        // Arrange
        _lockWithdrawal(STARK_KEY, address(_token), USER_TOKENS, LOCK_HASH);

        vm.assume(starkKeyY_ != STARK_KEY_Y);

        // Act + Assert
        vm.expectRevert(ECDSA.InvalidStarkKeyError.selector);
        IWithdrawalFacet(_bridge).claimWithdrawal(
            LOCK_HASH, abi.encode(SIGNATURE_R, SIGNATURE_S, starkKeyY_), vm.addr(1234)
        );
    }

    function test_claimWithdrawal_WhenSignatureWrongLength_InvalidSignatureError() public {
        // Act + Assert
        vm.expectRevert(IWithdrawalFacet.InvalidSignatureError.selector);
        IWithdrawalFacet(_bridge).claimWithdrawal(LOCK_HASH, abi.encode(0, 0), vm.addr(1234));
    }

    function test_claimWithdrawal_InvalidSignatureError() public {
        // Arrange
        _lockWithdrawal(STARK_KEY, address(_token), USER_TOKENS, LOCK_HASH);

        // Act + Assert
        vm.expectRevert(ECDSA.InvalidSignatureError.selector);
        IWithdrawalFacet(_bridge).claimWithdrawal(
            LOCK_HASH, abi.encode(SIGNATURE_R - 1, SIGNATURE_S, STARK_KEY_Y), vm.addr(1234)
        );
    }

    //==============================================================================//
    //=== reclaimWithdrawal Tests                                                ===//
    //==============================================================================//

    function test_reclaimWithdrawal_ok() public {
        // Arrange
        _lockWithdrawal(STARK_KEY, address(_token), USER_TOKENS, LOCK_HASH);

        // Arrange + Act + Assert
        _reclaimWithdrawal(LOCK_HASH, _recipient(), USER_TOKENS);
    }

    function test_reclaimWithdrawal_UnauthorizedError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.UnauthorizedError.selector));

        // Act + Assert
        IWithdrawalFacet(_bridge).reclaimWithdrawal(LOCK_HASH, _recipient());
    }

    function test_reclaimWithdrawal_InvalidLockHashError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(IWithdrawalFacet.InvalidLockHashError.selector));

        // Act + Assert
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).reclaimWithdrawal(0, _recipient());
    }

    function test_reclaimWithdrawal_ZeroAddressRecipientError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(IWithdrawalFacet.ZeroAddressRecipientError.selector));

        // Act + Assert
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).reclaimWithdrawal(123, address(0));
    }

    function test_reclaimWithdrawal_WithdrawalNotFoundError() public {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IWithdrawalFacet.WithdrawalNotFoundError.selector));

        // Act + Assert
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).reclaimWithdrawal(LOCK_HASH, _recipient());
    }

    function test_reclaimWithdrawal_WithdrawalNotExpiredError() public {
        // Arrange
        _lockWithdrawal(STARK_KEY, address(_token), USER_TOKENS, LOCK_HASH);
        // And
        vm.expectRevert(abi.encodeWithSelector(IWithdrawalFacet.WithdrawalNotExpiredError.selector));

        // Act + Assert
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).reclaimWithdrawal(LOCK_HASH, _recipient());
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _lockWithdrawal(uint256 starkKey_, address token_, uint256 amount_, uint256 lockHash_) private {
        // Arrange
        uint256 initialPendingWithdrawals_ = IWithdrawalFacet(_bridge).getPendingWithdrawals(token_);
        uint256 initialBalance_ = IERC20(token_).balanceOf(_bridge);
        // And
        MockERC20(token_).mint(_operator(), amount_);
        vm.prank(_operator());
        IERC20(token_).approve(address(_bridge), amount_);

        // Act + Assert
        vm.expectEmit(true, true, true, true);
        emit LogLockWithdrawal(lockHash_, starkKey_, token_, amount_);
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).lockWithdrawal(starkKey_, token_, amount_, lockHash_);

        // Assert
        // A withdrawal request was created.
        IWithdrawalFacet.Withdrawal memory withdrawal_ = IWithdrawalFacet(_bridge).getWithdrawal(lockHash_);
        assertEq(withdrawal_.starkKey, starkKey_);
        assertEq(withdrawal_.token, token_);
        assertEq(withdrawal_.amount, amount_);
        assertEq(withdrawal_.expirationDate, block.timestamp + IWithdrawalFacet(_bridge).getWithdrawalExpirationTimeout());
        // The accounting of pending withdrawals was updated.
        assertEq(IWithdrawalFacet(_bridge).getPendingWithdrawals(token_), initialPendingWithdrawals_ + amount_);
        assertEq(IERC20(token_).balanceOf(_bridge), initialBalance_ + amount_);
    }

    function _claimWithdrawal(uint256 lockHash_, bytes memory signature_, address recipient_, uint256 amount_)
        private
    {
        // Arrange
        uint256 initialBridgeBalance_ = _token.balanceOf(_bridge);
        uint256 initialRecipientBalance_ = _token.balanceOf(recipient_);
        uint256 initialPendingWithdrawals_ = IWithdrawalFacet(_bridge).getPendingWithdrawals(address(_token)); 
        // And
        vm.expectEmit(true, true, false, true);
        emit LogClaimWithdrawal(lockHash_, recipient_);

        // Assert
        vm.prank(recipient_); // anyone could claim this (auth is in the signature)
        IWithdrawalFacet(_bridge).claimWithdrawal(lockHash_, signature_, recipient_);

        // Assert
        // The withdrawal request was deleted
        _validateWithdrawalDeleted(lockHash_);

        // All balances were corretly updated
        assertEq(_token.balanceOf(_bridge), initialBridgeBalance_ - amount_);
        assertEq(_token.balanceOf(recipient_), initialRecipientBalance_ + amount_);
        assertEq(IWithdrawalFacet(_bridge).getPendingWithdrawals(address(_token)), initialPendingWithdrawals_ - amount_);
    }

    function _reclaimWithdrawal(uint256 lockHash_, address recipient_, uint256 amount_) private {
        // Arrange
        uint256 initialBridgeBalance_ = _token.balanceOf(_bridge);
        uint256 initialRecipientBalance_ = _token.balanceOf(recipient_);
        uint256 initialPendingWithdrawals_ = IWithdrawalFacet(_bridge).getPendingWithdrawals(address(_token)); 
        vm.warp(block.timestamp + IWithdrawalFacet(_bridge).getWithdrawalExpirationTimeout() + 1);

        // Act
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).reclaimWithdrawal(lockHash_, recipient_);

        // Assert
        // The withdrawal request was deleted
        _validateWithdrawalDeleted(lockHash_);
        // The expected _token amount was recalimed by the recipient
        assertEq(_token.balanceOf(recipient_), initialRecipientBalance_ + amount_);
        assertEq(_token.balanceOf(_bridge), initialBridgeBalance_ - amount_);
        assertEq(IWithdrawalFacet(_bridge).getPendingWithdrawals(address(_token)), initialPendingWithdrawals_ - amount_);
        
    }

    function _validateWithdrawalDeleted(uint256 lockHash_) internal {
        vm.expectRevert(abi.encodeWithSelector(IWithdrawalFacet.WithdrawalNotFoundError.selector));
        IWithdrawalFacet(_bridge).getWithdrawal(lockHash_);
    }
}
