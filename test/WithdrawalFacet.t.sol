//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/interfaces/IERC20.sol";

import { WithdrawalFacet }     from "src/facets/WithdrawalFacet.sol";
import { ECDSA }               from "src/dependencies/ecdsa/ECDSA.sol";
import { LibDiamond }          from "src/libraries/LibDiamond.sol";
import { ITokenRegisterFacet } from "src/interfaces/ITokenRegisterFacet.sol";
import { IWithdrawalFacet }    from "src/interfaces/IWithdrawalFacet.sol";
import { AppStorage }          from "src/storage/AppStorage.sol";

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { MockERC20 }   from "test/mocks/MockERC20.sol";

import { console2 as Console } from "@forge-std/console2.sol";

contract WithdrawalFacetTest is BaseFixture {

    //==============================================================================//
    //=== Constants                                                              ===//
    //==============================================================================//

    bytes4 internal constant ERC20_SELECTOR = bytes4(keccak256("ERC20Token(address)"));
    
    uint256 internal constant STARK_KEY   = 130079954696431488834386892570532580289305809527482364871420853057975493689;
    uint256 internal constant STARK_KEY_Y = 2014815737900971088087974256122814428168792651933467019210567933592263251564;
    
    /**
    AssetId Sold:       0x3003a65651d3b9fb2eff934a4416db301afd112a8492aaf8d7297fc87dcd9f4
    AssetId Fees:       70bf591713d7cb7150523cf64add8d49fa6b61036bba9f596bd2af8e3bb86f9
    Receiver Stark Key: 5fa3383597691ea9d827a79e1a4f0f7949435ced18ca9619de8ab97e661020
    VaultId Sender:     34
    VaultId Receiver:   21
    VaultId Fees:       593128169
    Nonce:              1
    Quantized Amount:   2154549703648910716
    Quantized Fee Max:  7
    Expiration:         1580230800
     */
    uint256 internal constant LOCK_HASH = 2356286878056985831279161846178161693107336866674377330568734796240516368603;

    uint256 internal SIGNATURE_R = 595786754653736406426889615487225077940077177382942628692506542715327069361;
    uint256 internal SIGNATURE_S = 1089493324092646311927517238061643471633017553425201144689187441352003681763;

    // R: 151340ef2d746eeba6e124262b50e52f0ceaedf4395c05e511fe671eb71bcb1
    // S: 268a1a1637989d491e88a95cba4d717b24d77a6a8473eef30746c2c3189fde3
    
    // X: ab0f8bcc2f64bdbe189004ea19c438a1163bf186e8818572d99f01e2846533d
    // Y: 068d3f3018870efc22178a84034bc81b6e1b2d100ccce1f7a327ee6e8e3ec87
    // Z: 6f1bc22178a84034bc81b6e1b2d100ccce1f7a327ee6e8e3ec876f1bc22178a840

    //==============================================================================//
    //=== Events                                                                 ===//
    //==============================================================================//

    event LogLockWithdrawal(uint256 indexed lockHash, uint256 indexed starkKey, address indexed asset, uint256 amount);
    event LogClaimWithdrawal(uint256 indexed lockHash, address indexed receiver);
    event LogReclaimWithdrawal(uint256 indexed lockHash, address indexed receiver);

    //==============================================================================//
    //=== State Variables                                                        ===//
    //==============================================================================//

    MockERC20 token;

    //==============================================================================//
    //=== Setup                                                                  ===//
    //==============================================================================//

    function setUp() override public {
        super.setUp();

        // Deploy token
        vm.prank(_tokenDeployer());
        token = (new MockERC20){salt: "USDC"}("USD Coin", "USDC", 6);   // 0xa33e385d3ab4a55cc949115bb5cb57fb16143d4b

        // Whitelist token admin
        ITokenRegisterFacet(bridge).setValidTokenAdmin(_tokenAdmin(), true);

        // Register token in bridge
        vm.prank(_tokenAdmin());
        ITokenRegisterFacet(bridge).registerToken(
            0x239763eb446b2ff4f1bfcbefbfb3756d28798fb7f17563f05f5cb1421712410,
            hex"F47261B0000000000000000000000000A33E385D3AB4A55CC949115BB5CB57FB16143D4B",  // (0xa33e385d3ab4a55cc949115bb5cb57fb16143d4b, 10000)
            10000
        );

        // Mint USDC to bridge
        token.mint(address(bridge), 1_000_000e6);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _lockWithdrawal(uint256 starkKey_, address asset_, uint256 amount_, uint256 lockHash_) private {
        // Arrange
        uint256 pendingWithdrawalsBefore_ = IWithdrawalFacet(bridge).getPendingWithdrawals(asset_);
        uint256 balanceBefore_ = IERC20(asset_).balanceOf(bridge);
        // and
        MockERC20(asset_).mint(_operator(), 1_000_000e6);
        vm.prank(_operator());
        IERC20(asset_).approve(address(bridge), amount_);
        // and
        vm.expectEmit(true, true, true, true);
        emit LogLockWithdrawal(lockHash_, starkKey_, asset_, amount_);

        // Act
        vm.prank(_operator());
        IWithdrawalFacet(bridge).lockWithdrawal(starkKey_, asset_, amount_, lockHash_);

        // Assert
        // A withdrawal request was created.
        AppStorage.Withdrawal memory withdrawal = IWithdrawalFacet(bridge).getWithdrawal(lockHash_);
        assertEq(withdrawal.starkKey, starkKey_);
        assertEq(withdrawal.asset, asset_);
        assertEq(withdrawal.amount, amount_);
        assertGt(withdrawal.expirationDate, 0);
        // The accounting of pending withdrawals was updated.
        assertEq(IWithdrawalFacet(bridge).getPendingWithdrawals(asset_), pendingWithdrawalsBefore_ + amount_);
        assertEq(IERC20(asset_).balanceOf(bridge), balanceBefore_ + amount_);
    }

    function _claimWithdrawal(uint256 lockHash_, bytes memory signature_, address recipient_, uint256 amount_) private {
        // Arrange
        uint256 bridgeBalanceBefore_ = token.balanceOf(bridge);
        uint256 recipientBalanceBefore_ = token.balanceOf(recipient_);
        uint256 pendingWithdrawalsBefore_ = IWithdrawalFacet(bridge).getPendingWithdrawals(address(token));  // TODO support multiple assets
        // and
        vm.expectEmit(true, true, false, true);
        emit LogClaimWithdrawal(lockHash_, recipient_);

        // Act
        vm.prank(vm.addr(999999));  // anyone can claim this (auth is made based on the validity of the signature)
        IWithdrawalFacet(bridge).claimWithdrawal(
            lockHash_,
            signature_,
            recipient_
        );

        // Assert
        // The withdrawal request was deleted
        AppStorage.Withdrawal memory withdrawal_ = IWithdrawalFacet(bridge).getWithdrawal(lockHash_);
        assertEq(withdrawal_.starkKey, 0);
        assertEq(withdrawal_.asset, address(0));
        assertEq(withdrawal_.amount, 0);
        assertEq(withdrawal_.expirationDate, 0);
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
        AppStorage.Withdrawal memory withdrawal_ = IWithdrawalFacet(bridge).getWithdrawal(lockHash_);
        assertEq(withdrawal_.starkKey, 0);
        assertEq(withdrawal_.asset, address(0));
        assertEq(withdrawal_.amount, 0);
        assertEq(withdrawal_.expirationDate, 0);
        // The expected token amount was recalimed by the recipient
        assertEq(token.balanceOf(recipient_), amount_);
        // TODO other
    }

    //==============================================================================//
    //=== Tests                                                                  ===//
    //==============================================================================//

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
        vm.expectRevert(abi.encodeWithSelector(
            WithdrawalFacet.WithdrawalNotFoundError.selector,
            LOCK_HASH
        ));

        // Act + Assert
        IWithdrawalFacet(bridge).claimWithdrawal(
            LOCK_HASH,
            abi.encode(SIGNATURE_R, SIGNATURE_S, STARK_KEY_Y),
            vm.addr(1234)
        );
    }

    function test_claimWithdrawal_InvalidStarkKeyError() public {
        // Arrange
        _lockWithdrawal(STARK_KEY, address(token), 100, LOCK_HASH);

        // Act + Assert
        vm.expectRevert(ECDSA.InvalidStarkKeyError.selector);
        IWithdrawalFacet(bridge).claimWithdrawal(
            LOCK_HASH,
            abi.encode(SIGNATURE_R, SIGNATURE_S, STARK_KEY_Y - 1),
            vm.addr(1234)
        );
    }

    function test_claimWithdrawal_InvalidSignatureError() public {
        // Arrange
        _lockWithdrawal(STARK_KEY, address(token), 100, LOCK_HASH);

        // Act + Assert
        vm.expectRevert(ECDSA.InvalidSignatureError.selector);
        IWithdrawalFacet(bridge).claimWithdrawal(
            LOCK_HASH,
            abi.encode(SIGNATURE_R - 1, SIGNATURE_S, STARK_KEY_Y),
            vm.addr(1234)
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