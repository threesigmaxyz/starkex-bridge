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

    MockERC20 token;

    //==============================================================================//
    //=== Setup                                                                  ===//
    //==============================================================================//

    function setUp() public override {
        super.setUp();

        // Deploy token
        vm.prank(_tokenDeployer());
        token = (new MockERC20){salt: "USDC"}("USD Coin", "USDC", 6); // 0xa33e385d3ab4a55cc949115bb5cb57fb16143d4b

        // Register token in bridge
        vm.prank(_tokenAdmin());
        ITokenRegisterFacet(bridge).setTokenRegister(address(token), true);

        // Mint USDC to bridge
        token.mint(address(bridge), 1_000_000e6);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _lockWithdrawal(uint256 starkKey_, address token_, uint256 amount_, uint256 lockHash_) private {
        // Arrange
        uint256 pendingWithdrawalsBefore_ = IWithdrawalFacet(bridge).getPendingWithdrawals(token_);
        uint256 balanceBefore_ = IERC20(token_).balanceOf(bridge);
        // and
        MockERC20(token_).mint(_operator(), 1_000_000e6);
        vm.prank(_operator());
        IERC20(token_).approve(address(bridge), amount_);
        // and
        vm.expectEmit(true, true, true, true);
        emit LogLockWithdrawal(lockHash_, starkKey_, token_, amount_);

        // Act
        vm.prank(_operator());
        IWithdrawalFacet(bridge).lockWithdrawal(starkKey_, token_, amount_, lockHash_);

        // Assert
        // A withdrawal request was created.
        IWithdrawalFacet.Withdrawal memory withdrawal = IWithdrawalFacet(bridge).getWithdrawal(lockHash_);
        assertEq(withdrawal.starkKey, starkKey_);
        assertEq(withdrawal.token, token_);
        assertEq(withdrawal.amount, amount_);
        assertGt(withdrawal.expirationDate, 0);
        // The accounting of pending withdrawals was updated.
        assertEq(IWithdrawalFacet(bridge).getPendingWithdrawals(token_), pendingWithdrawalsBefore_ + amount_);
        assertEq(IERC20(token_).balanceOf(bridge), balanceBefore_ + amount_);
    }

    function _claimWithdrawal(uint256 lockHash_, bytes memory signature_, address recipient_, uint256 amount_)
        private
    {
        // Arrange
        uint256 bridgeBalanceBefore_ = token.balanceOf(bridge);
        uint256 recipientBalanceBefore_ = token.balanceOf(recipient_);
        uint256 pendingWithdrawalsBefore_ = IWithdrawalFacet(bridge).getPendingWithdrawals(address(token)); // TODO support multiple tokens
        // and
        vm.expectEmit(true, true, false, true);
        emit LogClaimWithdrawal(lockHash_, recipient_);

        // Act
        vm.prank(vm.addr(999_999)); // anyone can claim this (auth is made based on the validity of the signature)
        IWithdrawalFacet(bridge).claimWithdrawal(lockHash_, signature_, recipient_);

        // Assert
        // The withdrawal request was deleted
        vm.expectRevert(abi.encodeWithSelector(IWithdrawalFacet.WithdrawalNotFoundError.selector));
        IWithdrawalFacet.Withdrawal memory withdrawal_ = IWithdrawalFacet(bridge).getWithdrawal(lockHash_);

        // All balances were corretly updateds
        assertEq(token.balanceOf(bridge), bridgeBalanceBefore_ - amount_);
        assertEq(token.balanceOf(recipient_), recipientBalanceBefore_ + amount_);
        assertEq(IWithdrawalFacet(bridge).getPendingWithdrawals(address(token)), pendingWithdrawalsBefore_ - amount_);
    }

    function _reclaimWithdrawal(uint256 lockHash_, address recipient_, uint256 amount_) private {
        // Arrange
        uint256 expiration_ = IWithdrawalFacet(bridge).getWithdrawal(lockHash_).expirationDate;
        assertGt(expiration_, 0);
        vm.warp(expiration_ + 1);
        // TODO assert event

        // Act
        vm.prank(_operator());
        IWithdrawalFacet(bridge).reclaimWithdrawal(lockHash_, recipient_);

        // Assert
        // The withdrawal request was deleted
        IWithdrawalFacet.Withdrawal memory withdrawal_ = IWithdrawalFacet(bridge).getWithdrawal(lockHash_);
        assertEq(withdrawal_.starkKey, 0);
        assertEq(withdrawal_.token, address(0));
        assertEq(withdrawal_.amount, 0);
        assertEq(withdrawal_.expirationDate, 0);
        // The expected token amount was recalimed by the recipient
        assertEq(token.balanceOf(recipient_), amount_);
        // TODO other
    }

    //==============================================================================//
    //=== Tests                                                                  ===//
    //==============================================================================//

    function test_withdrawal_initialize_ok() public {
        assertEq(
            IWithdrawalFacet(bridge).getWithdrawalExpirationTimeout(), Constants.WITHDRAWAL_ONCHAIN_EXPIRATION_TIMEOUT
        );
    }

    function test_set_withdrawalExpirationTimeout_ok() public {
        uint256 newTimeout = 500;
        vm.prank(_owner());
        IWithdrawalFacet(bridge).setWithdrawalExpirationTimeout(newTimeout);
        assertEq(IWithdrawalFacet(bridge).getWithdrawalExpirationTimeout(), newTimeout);
    }

    function test_set_withdrawalExpirationTimeout_notRole() public {
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.Unauthorized.selector));
        IWithdrawalFacet(bridge).setWithdrawalExpirationTimeout(999);
    }

    function test_lockWithdrawal_ok() public {
        _lockWithdrawal(STARK_KEY, address(token), 100, LOCK_HASH);
    }

    function test_claimWithdrawal_ok() public {
        // Arrange
        uint256 amount_ = 100;
        _lockWithdrawal(STARK_KEY, address(token), amount_, LOCK_HASH);
        // and
        address recipient_ = vm.addr(1234);
        bytes memory signature_ = abi.encode(SIGNATURE_R, SIGNATURE_S, STARK_KEY_Y);

        // Act + Assert
        _claimWithdrawal(LOCK_HASH, signature_, recipient_, amount_);
    }

    function test_claimWithdrawal_WithdrawalNotFoundError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(IWithdrawalFacet.WithdrawalNotFoundError.selector));

        // Act + Assert
        IWithdrawalFacet(bridge).claimWithdrawal(
            LOCK_HASH, abi.encode(SIGNATURE_R, SIGNATURE_S, STARK_KEY_Y), vm.addr(1234)
        );
    }

    function test_claimWithdrawal_InvalidStarkKeyError() public {
        // Arrange
        _lockWithdrawal(STARK_KEY, address(token), 100, LOCK_HASH);

        // Act + Assert
        vm.expectRevert(ECDSA.InvalidStarkKeyError.selector);
        IWithdrawalFacet(bridge).claimWithdrawal(
            LOCK_HASH, abi.encode(SIGNATURE_R, SIGNATURE_S, STARK_KEY_Y - 1), vm.addr(1234)
        );
    }

    function test_claimWithdrawal_InvalidSignatureError() public {
        // Arrange
        _lockWithdrawal(STARK_KEY, address(token), 100, LOCK_HASH);

        // Act + Assert
        vm.expectRevert(ECDSA.InvalidSignatureError.selector);
        IWithdrawalFacet(bridge).claimWithdrawal(
            LOCK_HASH, abi.encode(SIGNATURE_R - 1, SIGNATURE_S, STARK_KEY_Y), vm.addr(1234)
        );
    }

    /*
    TODO
    function test_reclaimWithdrawal_ok() public {
        // Arrange
        uint256 amount_ = 100;
        _lockWithdrawal(STARK_KEY, address(token), amount_, LOCK_HASH);

        // Act + Assert
        address recipient_ = vm.addr(1234);
        _reclaimWithdrawal(LOCK_HASH, recipient_, amount_);
    }

    function test_reclaimWithdrawal_notOperator_revert() public {
        // Arrange
        uint256 amount_ = 100;
        address recipient_ = vm.addr(1234);
        _lockWithdrawal(STARK_KEY, address(token), amount_, LOCK_HASH);

        // Act + Assert
        vm.expectRevert(abi.encodePacked("LibAccessControl: Must be StarkEx operator"));
        IWithdrawalFacet(bridge).reclaimWithdrawal(LOCK_HASH, recipient_);
    }

    function test_reclaimWithdrawal_alreadyUnlocked_revert() public {
        // Arrange
        uint256 amount_ = 100;
        address recipient_ = vm.addr(1234);
        _lockWithdrawal(STARK_KEY, address(token), amount_, LOCK_HASH);
        _reclaimWithdrawal(LOCK_HASH, recipient_, amount_);

        // Act + Assert
        vm.prank(_operator());
        vm.expectRevert(abi.encodePacked("CANT_UNLOCK"));
        IWithdrawalFacet(bridge).reclaimWithdrawal(LOCK_HASH, recipient_);
    }*/
}
