//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/interfaces/IERC20.sol";
import { ECDSA } from "src/dependencies/ecdsa/ECDSA.sol";

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { Constants } from "src/constants/Constants.sol";
import { LibDiamond } from "src/libraries/LibDiamond.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";

import { ITokenRegisterFacet } from "src/interfaces/facets/ITokenRegisterFacet.sol";
import { IWithdrawalFacet } from "src/interfaces/facets/IWithdrawalFacet.sol";

import { MockERC20 } from "test/mocks/MockERC20.sol";
import { HelpersECDSA } from "src/helpers/HelpersECDSA.sol";

contract WithdrawalFacetTest is BaseFixture {
    //==============================================================================//
    //=== Constants                                                              ===//
    //==============================================================================//

    /**
     * Real transfer message starkKeyX, starkKeyY, lockHash, r, s.
     */

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

    uint256 internal constant SIGNATURE_R =
        595_786_754_653_736_406_426_889_615_487_225_077_940_077_177_382_942_628_692_506_542_715_327_069_361;
    uint256 internal constant SIGNATURE_S =
        1_089_493_324_092_646_311_927_517_238_061_643_471_633_017_553_425_201_144_689_187_441_352_003_681_763;

    // R: 151340ef2d746eeba6e124262b50e52f0ceaedf4395c05e511fe671eb71bcb1
    // S: 268a1a1637989d491e88a95cba4d717b24d77a6a8473eef30746c2c3189fde3

    // X: ab0f8bcc2f64bdbe189004ea19c438a1163bf186e8818572d99f01e2846533d
    // Y: 068d3f3018870efc22178a84034bc81b6e1b2d100ccce1f7a327ee6e8e3ec87
    // Z: 6f1bc22178a84034bc81b6e1b2d100ccce1f7a327ee6e8e3ec876f1bc22178a840

    /**
     * Example messages, keys and signatures.
     * Obtained from:
     * https://github.com/starkware-libs/starkex-resources/tree/master/crypto/starkware/crypto/signature
     */

    uint256 internal constant TEST1_LOCK_HASH =
        2_768_498_024_101_110_746_696_508_142_221_047_236_812_821_820_792_692_622_141_175_702_701_103_930_225;
    uint256 internal constant TEST1_STARK_KEY =
        1_410_225_993_332_634_470_202_560_909_114_723_138_561_976_893_956_229_306_659_000_512_838_147_202_368;
    bytes internal constant TEST1_SIGNATURE = abi.encode(
        1_417_788_528_162_357_035_924_286_781_382_228_312_675_846_595_616_081_893_010_976_955_190_062_063_050,
        1_318_134_603_878_147_217_244_629_510_785_462_151_626_046_285_961_597_347_969_354_279_708_584_411_257,
        3_218_401_326_520_968_552_537_101_891_568_590_869_550_707_696_386_218_520_346_262_731_201_923_932_803
    );

    uint256 internal constant TEST2_LOCK_HASH =
        2_480_207_829_510_485_056_284_954_855_926_199_275_298_262_159_107_854_212_941_872_284_560_595_297_337;
    uint256 internal constant TEST2_STARK_KEY =
        393_519_290_310_313_169_176_754_085_449_142_119_068_983_495_536_535_633_569_553_387_859_779_093_537;
    bytes internal constant TEST2_SIGNATURE = abi.encode(
        2_789_139_206_898_324_895_113_446_948_241_743_896_238_588_727_971_229_863_189_676_057_206_614_028_577,
        1_725_473_343_147_954_267_477_796_972_742_114_362_211_416_311_070_107_670_152_257_415_557_686_585_975,
        3_357_823_828_217_307_413_273_536_559_741_209_184_995_235_490_907_709_188_314_694_614_739_399_372_145
    );

    uint256 internal constant TEST3_LOCK_HASH =
        3_590_286_349_374_207_174_270_012_308_800_953_866_517_252_228_506_574_589_862_927_360_690_715_980_751;
    uint256 internal constant TEST3_STARK_KEY =
        2_437_230_325_969_354_975_235_258_831_341_275_667_339_988_923_341_775_167_571_997_821_679_961_938_355;
    bytes internal constant TEST3_SIGNATURE = abi.encode(
        3_439_622_490_524_341_933_411_563_568_217_831_691_991_405_621_598_316_644_121_030_162_835_536_605_975,
        1_637_901_094_685_721_530_662_236_016_820_430_329_087_183_410_061_499_048_224_085_677_917_140_879_469,
        1_534_393_668_539_701_326_208_551_554_998_688_494_424_617_161_553_919_984_570_245_573_850_249_875_114
    );

    //==============================================================================//
    //=== Events                                                                 ===//
    //==============================================================================//

    event LogSetWithdrawalExpirationTimeout(uint256 indexed timeout);
    event LogLockWithdrawal(uint256 indexed lockHash, uint256 indexed starkKey, address indexed token, uint256 amount);
    event LogClaimWithdrawal(uint256 indexed lockHash, bytes indexed signature, address indexed receiver);
    event LogReclaimWithdrawal(uint256 indexed lockHash, address indexed receiver);

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

    function test_setWithdrawalExpirationTimeout_ok(uint256 timeout_) public {
        // Arrange
        vm.expectEmit(true, false, false, true, _bridge);
        emit LogSetWithdrawalExpirationTimeout(timeout_);

        vm.prank(_owner());
        IWithdrawalFacet(_bridge).setWithdrawalExpirationTimeout(timeout_);
        assertEq(IWithdrawalFacet(_bridge).getWithdrawalExpirationTimeout(), timeout_);
    }

    function test_setWithdrawalExpirationTimeout_UnauthorizedError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.UnauthorizedError.selector));

        // Act + Assert
        vm.prank(_intruder());
        IWithdrawalFacet(_bridge).setWithdrawalExpirationTimeout(999);
    }

    //==============================================================================//
    //=== lockWithdrawal Tests                                                   ===//
    //==============================================================================//

    function test_lockWithdrawal_ok(uint256 starkKey_, uint256 amount_, uint256 lockHash_) public {
        vm.assume(starkKey_ < Constants.K_MODULUS && HelpersECDSA.isOnCurve(starkKey_));
        vm.assume(amount_ > 0);
        vm.assume(lockHash_ > 0);

        // Act + Assert
        _lockWithdrawal(starkKey_, address(_token), amount_, lockHash_);
    }

    function test_lockWithdrawal_TokenNotRegisteredError() public {
        // Arrange
        address token_ = vm.addr(1);
        vm.label(token_, "token");
        vm.expectRevert(abi.encodeWithSelector(LibTokenRegister.TokenNotRegisteredError.selector, token_));

        // Act + Assert
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).lockWithdrawal(STARK_KEY, token_, USER_TOKENS, LOCK_HASH);
    }

    function test_lockWithdrawal_InvalidLockHashError() public {
        // Arrange
        uint256 lockHash_ = 0;
        vm.expectRevert(IWithdrawalFacet.InvalidLockHashError.selector);

        // Act + Assert
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).lockWithdrawal(STARK_KEY, address(_token), USER_TOKENS, lockHash_);
    }

    function test_lockWithdrawal_whenZeroStarkKey_InvalidStarkKeyError() public {
        // Arrange
        uint256 starkKey_ = 0;
        vm.expectRevert(IWithdrawalFacet.InvalidStarkKeyError.selector);

        // Act + Assert
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).lockWithdrawal(starkKey_, address(_token), USER_TOKENS, LOCK_HASH);
    }

    function test_lockWithdrawal_whenLargerThanModulusStarkKey_InvalidStarkKeyError(uint256 starkKey_) public {
        vm.assume(starkKey_ >= Constants.K_MODULUS);

        // Arrange
        vm.expectRevert(IWithdrawalFacet.InvalidStarkKeyError.selector);

        // Act + Assert
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).lockWithdrawal(starkKey_, address(_token), USER_TOKENS, LOCK_HASH);
    }

    function test_lockWithdrawal_whenNotInCurveStarkKey_InvalidStarkKeyError(uint256 starkKey_) public {
        vm.assume(HelpersECDSA.isOnCurve(starkKey_) == false);

        // Arrange
        vm.expectRevert(IWithdrawalFacet.InvalidStarkKeyError.selector);

        // Act + Assert
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).lockWithdrawal(STARK_KEY - 1, address(_token), USER_TOKENS, LOCK_HASH);
    }

    function test_lockWithdrawal_ZeroAmountError() public {
        // Arrange
        uint256 amount_ = 0;
        vm.expectRevert(IWithdrawalFacet.ZeroAmountError.selector);

        // Act + Assert
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).lockWithdrawal(STARK_KEY, address(_token), amount_, LOCK_HASH);
    }

    //==============================================================================//
    //=== claimWithdrawal Tests                                                  ===//
    //==============================================================================//

    function test_claimWithdrawal_ok() public {
        // Arrange
        bytes memory realTransferSignature_ = abi.encode(SIGNATURE_R, SIGNATURE_S, STARK_KEY_Y);

        // Act + Assert
        // LOCK_HASH corresponds to real transfer.
        _lockWithdrawal(STARK_KEY, address(_token), USER_TOKENS, LOCK_HASH);
        // Set the user as the recipient to repeat the tests afterwards.
        _claimWithdrawal(LOCK_HASH, realTransferSignature_, _user(), USER_TOKENS);
        // Test 1
        _lockWithdrawal(TEST1_STARK_KEY, address(_token), USER_TOKENS, TEST1_LOCK_HASH);
        _claimWithdrawal(TEST1_LOCK_HASH, TEST1_SIGNATURE, _user(), USER_TOKENS);
        // Test 2
        _lockWithdrawal(TEST2_STARK_KEY, address(_token), USER_TOKENS, TEST2_LOCK_HASH);
        _claimWithdrawal(TEST2_LOCK_HASH, TEST2_SIGNATURE, _user(), USER_TOKENS);
        // Test 3
        _lockWithdrawal(TEST3_STARK_KEY, address(_token), USER_TOKENS, TEST3_LOCK_HASH);
        _claimWithdrawal(TEST3_LOCK_HASH, TEST3_SIGNATURE, _user(), USER_TOKENS);
    }

    function test_claimWithdrawal_InvalidLockHashError() public {
        // Act + Assert
        vm.expectRevert(IWithdrawalFacet.InvalidLockHashError.selector);
        IWithdrawalFacet(_bridge).claimWithdrawal(0, abi.encode(0, 0, 0), _recipient());
    }

    function test_claimWithdrawal_ZeroAddressRecipientError() public {
        // Arrange
        address recipient_ = address(0);
        vm.expectRevert(IWithdrawalFacet.ZeroAddressRecipientError.selector);

        // Act + Assert
        IWithdrawalFacet(_bridge).claimWithdrawal(LOCK_HASH, abi.encode(0, 0, 0), recipient_);
    }

    function test_claimWithdrawal_WithdrawalNotFoundError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(IWithdrawalFacet.WithdrawalNotFoundError.selector));

        // Act + Assert
        IWithdrawalFacet(_bridge).claimWithdrawal(LOCK_HASH, abi.encode(1, 2, 3), _recipient());
    }

    function test_claimWithdrawal_InvalidStarkKeyYError(uint256 starkKeyY_) public {
        vm.assume(starkKeyY_ != STARK_KEY_Y);

        // Arrange
        _lockWithdrawal(STARK_KEY, address(_token), USER_TOKENS, LOCK_HASH);
        vm.expectRevert(ECDSA.InvalidStarkKeyError.selector);

        // Act + Assert
        IWithdrawalFacet(_bridge).claimWithdrawal(
            LOCK_HASH, abi.encode(SIGNATURE_R, SIGNATURE_S, starkKeyY_), _recipient()
        );
    }

    function test_claimWithdrawal_WhenSignatureWrongLength_InvalidSignatureError() public {
        // Arrange
        vm.expectRevert(IWithdrawalFacet.InvalidSignatureError.selector);

        // Act + Assert
        IWithdrawalFacet(_bridge).claimWithdrawal(LOCK_HASH, abi.encode(0, 0), _recipient());
    }

    function test_claimWithdrawal_InvalidSignatureError(bytes memory signature_) public {
        vm.assume(signature_.length == 32 * 3);
        // Arrange
        _lockWithdrawal(STARK_KEY, address(_token), USER_TOKENS, LOCK_HASH);

        // Act + Assert
        // Specific error is unknown because the ECDSA library has errors for different scenarios.
        vm.expectRevert();
        IWithdrawalFacet(_bridge).claimWithdrawal(LOCK_HASH, signature_, _recipient());
    }

    //==============================================================================//
    //=== reclaimWithdrawal Tests                                                ===//
    //==============================================================================//

    function test_reclaimWithdrawal_ok(uint256 lockHash_) public {
        vm.assume(lockHash_ > 0);

        // Arrange
        _lockWithdrawal(STARK_KEY, address(_token), USER_TOKENS, lockHash_);

        // Arrange + Act + Assert
        _reclaimWithdrawal(lockHash_, _recipient(), USER_TOKENS);
    }

    function test_reclaimWithdrawal_UnauthorizedError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.UnauthorizedError.selector));

        // Act + Assert
        IWithdrawalFacet(_bridge).reclaimWithdrawal(LOCK_HASH, _intruder());
    }

    function test_reclaimWithdrawal_InvalidLockHashError() public {
        // Arrange
        uint256 lockHash_ = 0;
        vm.expectRevert(abi.encodeWithSelector(IWithdrawalFacet.InvalidLockHashError.selector));

        // Act + Assert
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).reclaimWithdrawal(lockHash_, _recipient());
    }

    function test_reclaimWithdrawal_ZeroAddressRecipientError() public {
        // Arrange
        address recipient_ = address(0);
        vm.expectRevert(abi.encodeWithSelector(IWithdrawalFacet.ZeroAddressRecipientError.selector));

        // Act + Assert
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).reclaimWithdrawal(123, recipient_);
    }

    function test_reclaimWithdrawal_WithdrawalNotFoundError(uint256 lockHash_) public {
        vm.assume(lockHash_ > 0);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IWithdrawalFacet.WithdrawalNotFoundError.selector));

        // Act + Assert
        vm.prank(_operator());
        IWithdrawalFacet(_bridge).reclaimWithdrawal(lockHash_, _recipient());
    }

    function test_reclaimWithdrawal_WithdrawalNotExpiredError(uint256 timePassed_) public {
        vm.assume(timePassed_ <= block.timestamp + IWithdrawalFacet(_bridge).getWithdrawalExpirationTimeout());

        // Arrange
        _lockWithdrawal(STARK_KEY, address(_token), USER_TOKENS, LOCK_HASH);
        // And
        vm.expectRevert(abi.encodeWithSelector(IWithdrawalFacet.WithdrawalNotExpiredError.selector));

        // Act + Assert
        vm.warp(timePassed_);
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
        vm.prank(_user());
        MockERC20(token_).transfer(_operator(), amount_);
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
        assertEq(
            withdrawal_.expirationDate, block.timestamp + IWithdrawalFacet(_bridge).getWithdrawalExpirationTimeout()
        );
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
        emit LogClaimWithdrawal(lockHash_, signature_, recipient_);

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
        // And
        vm.expectEmit(true, true, false, true);
        emit LogReclaimWithdrawal(lockHash_, recipient_);
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
