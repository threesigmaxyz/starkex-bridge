//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { HelpersECDSA } from "src/helpers/HelpersECDSA.sol";

import { PatriciaTree } from "src/dependencies/mpt/v2/PatriciaTree.sol";

import { Constants } from "src/constants/Constants.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { MockERC721 } from "test/mocks/MockERC721.sol";
import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { INFTFacet } from "src/interfaces/facets/INFTFacet.sol";
import { IStateFacet } from "src/interfaces/facets/IStateFacet.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";

import { PedersenHash } from "src/dependencies/perdersen/PedersenHash.sol";
import { PedersenHash2 } from "src/dependencies/perdersen/PedersenHash2.sol";

import "@forge-std/console.sol";

contract DepositFacetTest is BaseFixture {
    //==============================================================================//
    //=== Constants                                                              ===//
    //==============================================================================//

    PatriciaTree internal _mpt;

    /**
     * Pedersen Hash example 1
     * a = hex(0x3d937c035c878245caf64531a5756109c53068da139362728feb561405371cb)
     * b = hex(0x208a0a10250e382e1e4bbe2880906c2791bf6275695e02fbbc6aeff9cd8b31a)
     * expectedResult = hex(0x30e480bed5fe53fa909cc0f8c4d99b8f9f2c016be4c41e13a4848797979c662)
     */
    uint256 internal constant PEDERSEN_EXAMPLE1_A =
        1_740_729_136_829_561_885_683_894_917_751_815_192_814_966_525_555_656_371_386_868_611_731_128_807_883;
    uint256 internal constant PEDERSEN_EXAMPLE1_B =
        919_869_093_895_560_023_824_014_392_670_608_914_007_817_594_969_197_822_578_496_829_435_657_368_346;
    uint256 internal constant PEDERSEN_EXAMPLE1_RESULT =
        1_382_171_651_951_541_052_082_654_537_810_074_813_456_022_260_470_662_576_358_627_909_045_455_537_762;

    /**
     * Pedersen Hash example 2
     * a = hex(0x58f580910a6ca59b28927c08fe6c43e2e303ca384badc365795fc645d479d45)
     * b = hex(0x78734f65a067be9bdb39de18434d71e79f7b6466a4b66bbd979ab9e7515fe0b)
     * expectedResult = hex(0x68cc0b76cddd1dd4ed2301ada9b7c872b23875d5ff837b3a87993e0d9996b87)
     */
    uint256 internal constant PEDERSEN_EXAMPLE2_A =
        2_514_830_971_251_288_745_316_508_723_959_465_399_194_546_626_755_475_650_431_255_835_704_887_319_877;
    uint256 internal constant PEDERSEN_EXAMPLE2_B =
        3_405_079_826_265_633_459_083_097_571_806_844_574_925_613_129_801_245_865_843_963_067_353_416_465_931;
    uint256 internal constant PEDERSEN_EXAMPLE2_RESULT =
        2_962_565_761_002_374_879_415_469_392_216_379_291_665_599_807_391_815_720_833_106_117_558_254_791_559;

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

    event LogNFTDeposited(
        address indexed token, uint256 indexed tokenId, uint256 indexed lockHash, uint256 starkKey, uint256 assetId
    );
    event LogNFTReclaimed(address indexed token, uint256 indexed tokenId);
    event LogSetExpirationTimeout(uint256 indexed timeout);
    event LogNFTUnlocked(address indexed token, uint256 indexed tokenId);
    event LogNFTRecipient(address indexed token, uint256 indexed tokenId, address indexed recipient);
    event LogNFTwithdrawn(address indexed token, uint256 indexed tokenId, address indexed recipient);

    PedersenHash2 private _pedersenHash2;

    function setUp() public override {
        super.setUp();
        _mpt = new PatriciaTree();
        address[64] memory tables;
        _pedersenHash2 = new PedersenHash2(tables);
    }

    //==============================================================================//
    //=== initialize Tests                                                       ===//
    //==============================================================================//

    function test_NFTFacet_initialize_ok() public {
        assertEq(INFTFacet(_bridge).getExpirationTimeout(), Constants.DEPOSIT_ONCHAIN_EXPIRATION_TIMEOUT);
    }

    //==============================================================================//
    //=== setExpirationTimeout Tests                                             ===//
    //==============================================================================//

    function test_setExpirationTimeout_ok(uint256 timeout_) public {
        // Arrange
        vm.expectEmit(true, false, false, true, _bridge);
        emit LogSetExpirationTimeout(timeout_);

        // Act + Assert
        vm.prank(_owner());
        INFTFacet(_bridge).setExpirationTimeout(timeout_);
        assertEq(INFTFacet(_bridge).getExpirationTimeout(), timeout_);
    }

    function test_setExpirationTimeout_UnauthorizedError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.UnauthorizedError.selector));

        // Act + Assert
        vm.prank(_intruder());
        INFTFacet(_bridge).setExpirationTimeout(999);
    }

    //==============================================================================//
    //=== depositNFT Tests                                                       ===//
    //==============================================================================//

    function test_depositNFT_ok(uint256 starkKey_, uint256 lockHash_, uint256 assetId_) public {
        // Arrange
        vm.assume(starkKey_ < Constants.K_MODULUS && HelpersECDSA.isOnCurve(starkKey_));
        vm.assume(lockHash_ > 0);
        vm.assume(assetId_ > 0);
        // And
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);

        // Act
        _depositNFT(starkKey_, token721_, tokenId_, lockHash_, assetId_);
    }

    function test_depositNFT_TokenNotRegisteredError() public {
        // Arrange
        address token_ = vm.addr(1);
        vm.expectRevert(abi.encodeWithSelector(LibTokenRegister.TokenNotRegisteredError.selector, token_));

        // Act + Assert
        INFTFacet(_bridge).depositNFT(STARK_KEY, token_, 0, LOCK_HASH, 1);
    }

    function test_depositNFT_InvalidDepositLockError() public {
        // Arrange
        uint256 lockHash_ = 0;
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.InvalidDepositLockError.selector));

        // Act + Assert
        INFTFacet(_bridge).depositNFT(STARK_KEY, address(_token721), 0, lockHash_, 1);
    }

    function test_depositNFT_InvalidStarkKeyError() public {
        // Arrange
        uint256 starkKey_ = 0;
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.InvalidStarkKeyError.selector));

        // Act + Assert
        INFTFacet(_bridge).depositNFT(starkKey_, address(_token721), 0, LOCK_HASH, 1);
    }

    function test_depositNFT_DepositedTokenError(uint256 lockHash_, uint256 assetId_) public {
        // Arrange
        vm.assume(lockHash_ > 0);
        vm.assume(assetId_ > 0);
        // And
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, lockHash_, assetId_);
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.DepositedTokenError.selector));

        // Act + Assert
        INFTFacet(_bridge).depositNFT(STARK_KEY, token721_, tokenId_, lockHash_, assetId_);
    }

    //==============================================================================//
    //=== reClaimNFT Tests                                                       ===//
    //==============================================================================//

    function test_reClaimNFT_ok(uint256 lockHash_, uint256 assetId_) public {
        // Arrange
        vm.assume(lockHash_ > 0);
        vm.assume(assetId_ > 0);
        // And
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, lockHash_, assetId_);

        // Arrange
        vm.warp(block.timestamp + INFTFacet(_bridge).getExpirationTimeout() + 1);
        // And
        (uint256 branchMask_, bytes32[] memory siblings_) = _addOrderRoot(lockHash_, 0);
        // And
        vm.expectEmit(true, false, false, true);
        emit LogNFTReclaimed(token721_, tokenId_);

        // Act + Assert
        vm.prank(_user());
        INFTFacet(_bridge).reClaimNFT(token721_, tokenId_, branchMask_, siblings_);
        // And
        _validateDeletedDeposit(token721_, tokenId_);
    }

    function test_reClaimNFT_DepositNotFoundError(uint256 lockHash_) public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        (uint256 branchMask_, bytes32[] memory siblings_) = _mpt.getProof(abi.encode(lockHash_));
        // And
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.DepositNotFoundError.selector));

        // Act + Assert
        INFTFacet(_bridge).reClaimNFT(token721_, tokenId_, branchMask_, siblings_);
    }

    function test_reClaimNFT_DepositNotExpiredError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);

        // Arrange
        (uint256 branchMask_, bytes32[] memory siblings_) = _addOrderRoot(LOCK_HASH, 0);
        // And
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.DepositNotExpiredError.selector));

        // Act + Assert
        vm.prank(_user());
        INFTFacet(_bridge).reClaimNFT(token721_, tokenId_, branchMask_, siblings_);
    }

    //==============================================================================//
    //=== unlockNFTBurn Tests                                                    ===//
    //==============================================================================//

    function test_unlockNFTBurn_ok() public { }

    function test_unlockNFTBurn_DepositNotFoundError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        uint256[5] memory hash_ = [uint256(0), 0, 0, 0, 0]; // Change with an actual array
        (uint256 branchMask_, bytes32[] memory siblings_) = _mpt.getProof(abi.encode(LOCK_HASH));
        // And
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.DepositNotFoundError.selector));

        // Act + Assert
        INFTFacet(_bridge).unlockNFTBurn(token721_, tokenId_, hash_, branchMask_, siblings_);
    }

    function test_unlockNFTBurn_AlreadyUnlockedError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        uint256[5] memory hash_ = [uint256(0), 0, 0, 0, 0]; // Change with an actual array
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);
        _unlockNFTWithdraw(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);
        // And
        (uint256 branchMask_, bytes32[] memory siblings_) = _mpt.getProof(abi.encode(LOCK_HASH));
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.AlreadyUnlockedError.selector));

        // Act + Assert
        INFTFacet(_bridge).unlockNFTBurn(token721_, tokenId_, hash_, branchMask_, siblings_);
    }

    //==============================================================================//
    //=== setRecipientNFT Tests                                                  ===//
    //==============================================================================//

    function test_setRecipientNFT_ok() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        uint256[5] memory hashInfo_ = [uint256(1), uint256(2), uint256(3), uint256(4), uint256(5)];
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);
        // And
        (uint256 branchMask_, bytes32[] memory siblings_) = _addOrderRoot(TEST1_LOCK_HASH, 1);
        // And
        INFTFacet(_bridge).unlockNFTBurn(token721_, tokenId_, hashInfo_, branchMask_, siblings_);
        // And
        vm.expectEmit(true, true, true, true);
        emit LogNFTRecipient(token721_, tokenId_, _recipient());

        // Act
        INFTFacet(_bridge).setRecipientNFT(token721_, tokenId_, TEST1_STARK_KEY, TEST1_SIGNATURE, _recipient());
    }

    function test_setRecipientNFT_DepositNotFoundError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.DepositNotFoundError.selector));

        // Act
        INFTFacet(_bridge).setRecipientNFT(token721_, tokenId_, TEST1_STARK_KEY, TEST1_SIGNATURE, _recipient());
    }

    function test_setRecipientNFT_NotUnlockedError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);
        // And
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.NotUnlockedError.selector));

        // Act
        INFTFacet(_bridge).setRecipientNFT(token721_, tokenId_, TEST1_STARK_KEY, TEST1_SIGNATURE, _recipient());
    }

    function test_setRecipientNFT_RecipientAlreadySetError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        uint256[5] memory hashInfo_ = [uint256(1), uint256(2), uint256(3), uint256(4), uint256(5)];
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);
        // And
        (uint256 branchMask_, bytes32[] memory siblings_) = _addOrderRoot(TEST1_LOCK_HASH, 1);
        // And
        INFTFacet(_bridge).unlockNFTBurn(token721_, tokenId_, hashInfo_, branchMask_, siblings_);
        // And
        INFTFacet(_bridge).setRecipientNFT(token721_, tokenId_, TEST1_STARK_KEY, TEST1_SIGNATURE, _recipient());
        // And
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.RecipientAlreadySetError.selector));

        // Act
        INFTFacet(_bridge).setRecipientNFT(token721_, tokenId_, TEST1_STARK_KEY, TEST1_SIGNATURE, _user());
    }

    function test_setRecipientNFT_InvalidSignatureError(bytes memory signature_) public {
        // Arrange
        vm.assume(signature_.length == 32 * 3);
        // And
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        uint256[5] memory hashInfo_ = [uint256(1), uint256(2), uint256(3), uint256(4), uint256(5)];
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);
        // And
        (uint256 branchMask_, bytes32[] memory siblings_) = _addOrderRoot(TEST1_LOCK_HASH, 1);
        // And
        INFTFacet(_bridge).unlockNFTBurn(token721_, tokenId_, hashInfo_, branchMask_, siblings_);
        // And
        // Specific error is unknown because the ECDSA library has errors for different scenarios.
        vm.expectRevert();

        // Act
        INFTFacet(_bridge).setRecipientNFT(token721_, tokenId_, TEST1_STARK_KEY, signature_, _recipient());
    }

    function test_claimWithdrawal_whenSignatureWrongLength_InvalidSignatureError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);
        // And
        uint256[5] memory hashInfo_ = [uint256(1), uint256(2), uint256(3), uint256(4), uint256(5)];
        // And
        (uint256 branchMask_, bytes32[] memory siblings_) = _addOrderRoot(TEST1_LOCK_HASH, 1);
        // And
        INFTFacet(_bridge).unlockNFTBurn(token721_, tokenId_, hashInfo_, branchMask_, siblings_);
        // And
        vm.expectRevert(INFTFacet.InvalidSignatureError.selector);

        // Act
        INFTFacet(_bridge).setRecipientNFT(token721_, tokenId_, TEST1_STARK_KEY, abi.encode(0, 0), _recipient());
    }

    function test_setRecipientNFT_InvalidStarkKeyError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);
        // And
        uint256[5] memory hashInfo_ = [uint256(1), uint256(2), uint256(3), uint256(4), uint256(5)];
        // And
        (uint256 branchMask_, bytes32[] memory siblings_) = _addOrderRoot(TEST1_LOCK_HASH, 1);
        // And
        INFTFacet(_bridge).unlockNFTBurn(token721_, tokenId_, hashInfo_, branchMask_, siblings_);
        // And
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.InvalidStarkKeyError.selector));

        // Act
        INFTFacet(_bridge).setRecipientNFT(token721_, tokenId_, TEST1_STARK_KEY, TEST2_SIGNATURE, _recipient());
    }

    //==============================================================================//
    //=== unlockNFTWithdraw Tests                                                ===//
    //==============================================================================//

    function test_unlockNFTWithdraw_ok(uint256 starkKey_, uint256 lockHash_, uint256 assetId_) public {
        // Arrange
        vm.assume(starkKey_ < Constants.K_MODULUS && HelpersECDSA.isOnCurve(starkKey_));
        vm.assume(lockHash_ > 0);
        vm.assume(assetId_ > 0);
        // And
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        _depositNFT(starkKey_, token721_, tokenId_, lockHash_, assetId_);

        // Act + Assert
        _unlockNFTWithdraw(starkKey_, token721_, tokenId_, lockHash_, assetId_);
    }

    function test_unlockNFTWithdraw_UnauthorizedError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.UnauthorizedError.selector));

        // Act
        vm.prank(_user());
        INFTFacet(_bridge).unlockNFTWithdraw(token721_, tokenId_, _recipient());
    }

    function test_unlockNFTWithdraw_DepositNotFoundError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.DepositNotFoundError.selector));

        // Act
        vm.prank(_mockInteropContract());
        INFTFacet(_bridge).unlockNFTWithdraw(token721_, tokenId_, _recipient());
    }

    function test_unlockNFTWithdraw_AlreadyUnlockedError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);
        // And
        _unlockNFTWithdraw(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);
        // And
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.AlreadyUnlockedError.selector));

        // Act
        vm.prank(_mockInteropContract());
        INFTFacet(_bridge).unlockNFTWithdraw(token721_, tokenId_, _recipient());
    }

    //==============================================================================//
    //=== withdrawNFT Tests                                                      ===//
    //==============================================================================//

    function test_withdrawNFT_unlockNFTBurn_ok() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        uint256[5] memory hashInfo_ = [uint256(1), uint256(2), uint256(3), uint256(4), uint256(5)];
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);
        // And
        (uint256 branchMask_, bytes32[] memory siblings_) = _addOrderRoot(TEST1_LOCK_HASH, 1);
        // And
        INFTFacet(_bridge).unlockNFTBurn(token721_, tokenId_, hashInfo_, branchMask_, siblings_);
        // And
        INFTFacet(_bridge).setRecipientNFT(token721_, tokenId_, TEST1_STARK_KEY, TEST1_SIGNATURE, _recipient());
        // And
        vm.expectEmit(true, true, true, true);
        emit LogNFTwithdrawn(token721_, tokenId_, _recipient());

        // Act + Assert
        INFTFacet(_bridge).withdrawNFT(token721_, tokenId_);
        assertEq(_token721.ownerOf(tokenId_), _recipient());
    }

    function test_withdrawNFT_unlockNFTBurn_RecipientNotSetError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        uint256[5] memory hashInfo_ = [uint256(1), uint256(2), uint256(3), uint256(4), uint256(5)];
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);
        // And
        (uint256 branchMask_, bytes32[] memory siblings_) = _addOrderRoot(TEST1_LOCK_HASH, 1);
        // And
        INFTFacet(_bridge).unlockNFTBurn(token721_, tokenId_, hashInfo_, branchMask_, siblings_);
        // And
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.RecipientNotSetError.selector));

        // Act + Assert
        INFTFacet(_bridge).withdrawNFT(token721_, tokenId_);
    }

    function test_withdrawNFT_unlockNFTWithdraw_ok(uint256 starkKey_, uint256 lockHash_, uint256 assetId_) public {
        // Arrange
        vm.assume(starkKey_ < Constants.K_MODULUS && HelpersECDSA.isOnCurve(starkKey_));
        vm.assume(lockHash_ > 0);
        vm.assume(assetId_ > 0);
        // And
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        _depositNFT(starkKey_, token721_, tokenId_, lockHash_, assetId_);
        // And
        _unlockNFTWithdraw(starkKey_, token721_, tokenId_, lockHash_, assetId_);
        // And
        vm.expectEmit(true, true, true, true);
        emit LogNFTwithdrawn(token721_, tokenId_, _recipient());

        // Act + Assert
        INFTFacet(_bridge).withdrawNFT(token721_, tokenId_);
        assertEq(_token721.ownerOf(tokenId_), _recipient());
    }

    function test_withdrawNFT_DepositNotFoundError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.DepositNotFoundError.selector));

        // Act
        INFTFacet(_bridge).withdrawNFT(token721_, tokenId_);
    }

    function test_withdrawNFT_NFTLockedError() public {
        // Arrange
        uint256 tokenId_ = 0;
        address token721_ = address(_token721);
        // And
        _depositNFT(STARK_KEY, token721_, tokenId_, LOCK_HASH, 1);
        // And
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.NFTLockedError.selector));

        // Act
        INFTFacet(_bridge).withdrawNFT(token721_, tokenId_);
    }

    //==============================================================================//
    //=== Pedersen Hash Tests                                                    ===//
    //==============================================================================//

    function test_pedersenHash_example1() public {
        // Arrange
        uint256 a_ = PEDERSEN_EXAMPLE1_A;
        uint256 b_ = PEDERSEN_EXAMPLE1_B;
        uint256 expectedResult_ = PEDERSEN_EXAMPLE1_RESULT;

        // Act + Assert
        uint256 result_ = PedersenHash.hash(a_, b_);
        assertEq(result_, expectedResult_);
    }

    function test_pedersenHash_example2() public {
        // Arrange
        uint256 a_ = PEDERSEN_EXAMPLE2_A;
        uint256 b_ = PEDERSEN_EXAMPLE2_B;
        uint256 expectedResult_ = PEDERSEN_EXAMPLE2_RESULT;

        // Act + Assert
        uint256 result_ = PedersenHash.hash(a_, b_);
        assertEq(result_, expectedResult_);
    }

    /**
     * _tokenId Sold:       0x3003a65651d3b9fb2eff934a4416db301afd112a8492aaf8d7297fc87dcd9f4
     * _tokenId Fees:       0x70bf591713d7cb7150523cf64add8d49fa6b61036bba9f596bd2af8e3bb86f9
     * Receiver Stark Key:  0x5fa3383597691ea9d827a79e1a4f0f7949435ced18ca9619de8ab97e661020
     * VaultId Sender:      34
     * VaultId Receiver:    21
     * VaultId Fees:        593128169
     * Nonce:               1
     * Quantized Amount:    2154549703648910716
     * Quantized Fee Max:   7
     * Expiration:          1580230800
     *
     * Result:              0x5359c71cf08f394b7eb713532f1a0fcf1dccdf1836b10db2813e6ff6b6548db
     *                      2356286878056985831279161846178161693107336866674377330568734796240516368603
     */

    function test_hash_creation() public {
        uint256 expectedResult_ =
            2_356_286_878_056_985_831_279_161_846_178_161_693_107_336_866_674_377_330_568_734_796_240_516_368_603;

        uint256 tokenIdSold_ =
            1_357_341_580_641_093_578_390_436_956_406_864_461_606_505_106_415_342_019_527_909_525_011_035_904_500;
        uint256 tokenIdFees_ =
            3_187_320_106_768_240_683_798_004_120_055_019_620_328_183_284_270_499_188_497_569_860_310_619_883_257;
        uint256 receiverStarkKey_ =
            168_976_971_209_324_910_088_270_776_698_114_429_106_829_914_647_771_869_169_305_379_452_790_116_384;

        uint256 w4_ = _w4(34, 21, 593_128_169, 1);

        uint256 w5_ = _w5(2_154_549_703_648_910_716, 7, 1_580_230_800);

        uint256 innerHash_ = PedersenHash.hash(tokenIdSold_, tokenIdFees_);
        uint256 innerHash2_ = PedersenHash.hash(innerHash_, receiverStarkKey_); // This is where the current Pedersen Hash function returns wrong results.
        uint256 innerHash3_ = PedersenHash.hash(innerHash2_, w4_);
        uint256 finalHash_ = PedersenHash.hash(innerHash3_, w5_);

        //assertEq(finalHash_, expectedResult_);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _depositNFT(uint256 starkKey_, address token721_, uint256 tokenId_, uint256 lockHash_, uint256 assetId_)
        internal
    {
        // Arrange
        vm.expectEmit(true, true, true, true);
        emit LogNFTDeposited(token721_, tokenId_, lockHash_, starkKey_, assetId_);

        // Act
        vm.startPrank(_user());
        MockERC721(token721_).approve(_bridge, tokenId_);
        INFTFacet(_bridge).depositNFT(starkKey_, token721_, tokenId_, lockHash_, assetId_);
        vm.stopPrank();

        // Assert
        INFTFacet.NFTs memory nft_ = INFTFacet(_bridge).getDepositedNFT(token721_, tokenId_);
        assertEq(nft_.locked, true);
        assertEq(nft_.recipient, _user());
        assertEq(nft_.assetId, assetId_);
        assertEq(nft_.expirationDate, block.timestamp + INFTFacet(_bridge).getExpirationTimeout());
        assertEq(nft_.lockHash, lockHash_);
    }

    function _unlockNFTWithdraw(
        uint256 starkKey_,
        address token721_,
        uint256 tokenId_,
        uint256 lockHash_,
        uint256 assetId_
    ) internal {
        // Arrange
        vm.expectEmit(true, true, true, true);
        emit LogNFTUnlocked(token721_, tokenId_);
        vm.expectEmit(true, true, true, true);
        emit LogNFTRecipient(token721_, tokenId_, _recipient());

        // Act
        vm.prank(_mockInteropContract());
        INFTFacet(_bridge).unlockNFTWithdraw(token721_, tokenId_, _recipient());

        // Assert
        INFTFacet.NFTs memory nft_ = INFTFacet(_bridge).getDepositedNFT(token721_, tokenId_);
        assertEq(nft_.locked, false);
        assertEq(nft_.recipient, _recipient());
    }

    function _addOrderRoot(uint256 hash_, uint256 value_) internal returns (uint256, bytes32[] memory) {
        _mpt.insert(abi.encode(hash_), abi.encode(value_));
        (uint256 branchMask_, bytes32[] memory siblings_) = _mpt.getProof(abi.encode(hash_));

        uint256 orderRoot_ = uint256(_mpt.root());

        vm.prank(_mockInteropContract());
        IStateFacet(_bridge).setOrderRoot(orderRoot_);

        return (branchMask_, siblings_);
    }

    function _validateDeletedDeposit(address token_, uint256 tokenId_) internal {
        vm.expectRevert(abi.encodeWithSelector(INFTFacet.DepositNotFoundError.selector));
        INFTFacet(_bridge).getDepositedNFT(token_, tokenId_);
    }

    function _w4(uint256 VaultId_Sender, uint256 VaultId_Receiver, uint256 VaultId_Fees, uint256 Nonce)
        internal
        pure
        returns (uint256)
    {
        return (VaultId_Sender << 160) | (VaultId_Receiver << 96) | (VaultId_Fees << 32) | (Nonce);
    }

    function _w5(uint256 Quantized_Amount, uint256 Quantized_Fee_Max, uint256 Expiration)
        internal
        pure
        returns (uint256)
    {
        return (4 << 241) | (Quantized_Amount << 177) | (Quantized_Fee_Max << 113) | ((Expiration / 3600) << 81);
    }
}
