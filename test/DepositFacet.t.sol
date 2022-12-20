//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Constants }           from "src/constants/Constants.sol";
import { DepositFacet }        from "src/facets/DepositFacet.sol";
import { IAccessControlFacet } from "src/interfaces/IAccessControlFacet.sol";
import { IDepositFacet }       from "src/interfaces/IDepositFacet.sol";
import { IStateFacet }         from "src/interfaces/IStateFacet.sol";
import { ITokenRegisterFacet } from "src/interfaces/ITokenRegisterFacet.sol";
import { PatriciaTree }        from "src/dependencies/mpt/v2/PatriciaTree.sol";
import { LibAccessControl }    from "src/libraries/LibAccessControl.sol";

import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { MockERC20 }   from "test/mocks/MockERC20.sol";

import { console2 as Console } from "@forge-std/console2.sol";

contract DepositFacetTest is BaseFixture {

    //==============================================================================//
    //=== Constants                                                              ===//
    //==============================================================================//

    uint256 internal constant STARK_KEY = 1234;

    /**
    tokenId Sold:       0x3003a65651d3b9fb2eff934a4416db301afd112a8492aaf8d7297fc87dcd9f4
    tokenId Fees:       70bf591713d7cb7150523cf64add8d49fa6b61036bba9f596bd2af8e3bb86f9
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

    //==============================================================================//
    //=== Events                                                                 ===//
    //==============================================================================//

	event LogLockDeposit(uint256 indexed lockHash, uint256 indexed starkKey, address indexed token, uint256 amount);
    event LogClaimDeposit(uint256 indexed lockHash, address indexed recipient);
    event LogReclaimDeposit(uint256 indexed lockHash);

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
        Console.log(address(token));

        // Register token in bridge
        vm.prank(_tokenAdmin());
        ITokenRegisterFacet(bridge).setTokenRegister(address(token), true);
    }

    function test_deposit_initialize_ok() public {
        assertEq(IDepositFacet(bridge).getDepositExpirationTimeout(), Constants.DEPOSIT_ONCHAIN_EXPIRATION_TIMEOUT);
    }

    function test_set_depositExpirationTimeout_ok() public {
        uint256 newTimeout = 500;
        vm.prank(_owner());
        IDepositFacet(bridge).setDepositExpirationTimeout(newTimeout);
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
        _lockDeposit(vm.addr(1), STARK_KEY, address(token), 100, LOCK_HASH);
    }

    /*
    TODO
    function test_lockDeposit_WhentokenNotRegistered_tokenNotRegisteredError() public {
        // Arrange
        address token_ = vm.addr(12345);

        // Act + Assert
        vm.expectRevert(
            abi.encodeWithSelector(Modifiers.tokenNotRegisteredError.selector, token_)
        );
        IDepositFacet(bridge).lockDeposit(STARK_KEY, token_, 888, LOCK_HASH);
    }*/

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
        address depositor_ = vm.addr(7829);
        _lockDeposit(depositor_, STARK_KEY, address(token), 888, LOCK_HASH);

        // Act + Assert
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositPendingError.selector));
        IDepositFacet(bridge).lockDeposit(STARK_KEY, address(token), 888, LOCK_HASH);
    }

    // TODO lockDeposit not enough balance...

    //==============================================================================//
    //=== claimDeposit Tests                                                     ===//
    //==============================================================================//

    function test_claimDeposit_ok() public {
        // Arrange
        uint256 amount_ = 100;
        _lockDeposit(vm.addr(1), STARK_KEY, address(token), amount_, LOCK_HASH);
        // and
        PatriciaTree mpt_ = new PatriciaTree();
        mpt_.insert(abi.encode(LOCK_HASH), abi.encode(1));
        (uint256 branchMask_, bytes32[] memory siblings_) = mpt_.getProof(abi.encode(LOCK_HASH));
        uint256 orderRoot_ = uint256(mpt_.root());
        // and
        vm.prank(_owner());
        IAccessControlFacet(bridge).setPendingRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE, _mockInteropContract());
        
        vm.prank(_mockInteropContract());
        IAccessControlFacet(bridge).acceptRole(LibAccessControl.INTEROPERABILITY_CONTRACT_ROLE);
        // and
        vm.prank(_mockInteropContract());
        IStateFacet(bridge).setOrderRoot(orderRoot_);

        // Act + Assert
        address recipient_ = vm.addr(777);
        _claimDeposit(LOCK_HASH, branchMask_, siblings_, recipient_);
    }

    //==============================================================================//
    //=== reclaimDeposit Tests                                                   ===//
    //==============================================================================//

    function test_reclaimDeposit_ok() public {
        // Arrange
        uint256 amount_ = 100;
        _lockDeposit(vm.addr(1), STARK_KEY, address(token), amount_, LOCK_HASH);

        // Act + Assert
        _reclaimDeposit(LOCK_HASH);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _lockDeposit(
        address user_,
        uint256 starkKey_,
		address token_,
		uint256 amount_,
		uint256 lockHash_
    ) internal {
        // Arrange
        MockERC20(token_).mint(user_, amount_);
        vm.prank(user_);
        MockERC20(token_).approve(address(bridge), amount_);

        // Act
        vm.expectEmit(true, true, true, true);
        emit LogLockDeposit(lockHash_, starkKey_, token_, amount_);
        vm.prank(user_);
        IDepositFacet(bridge).lockDeposit(starkKey_, token_, amount_, lockHash_);

        // Assert
        IDepositFacet.Deposit memory deposit_ = IDepositFacet(bridge).getDeposit(lockHash_);
        assertEq(deposit_.receiver, user_);
        assertEq(deposit_.starkKey, starkKey_);
        assertEq(deposit_.token, token_);
        assertEq(deposit_.amount, amount_);
        assertEq(deposit_.expirationDate, block.timestamp + Constants.DEPOSIT_ONCHAIN_EXPIRATION_TIMEOUT);
    }

    function _claimDeposit(
        uint256 lockHash_,
        uint256 branchMask_,
        bytes32[] memory proof_,
        address recipient_
    ) internal {
        // Arrange
        IDepositFacet.Deposit memory deposit_ = IDepositFacet(bridge).getDeposit(lockHash_);
        assertGt(deposit_.expirationDate, 0);
        vm.warp(deposit_.expirationDate + 1);

        // Act
        vm.expectEmit(true, true, false, true);
        emit LogClaimDeposit(lockHash_, recipient_);
        vm.prank(_operator());
        IDepositFacet(bridge).claimDeposit(
            lockHash_,
            branchMask_,
            proof_,
            recipient_
        );

        // Assert
        _validateDepositDeleted(lockHash_);
        // And
        assertEq(MockERC20(deposit_.token).balanceOf(recipient_), deposit_.amount);
    }

    function _reclaimDeposit(uint256 lockHash_) internal {
        // Arrange
        IDepositFacet.Deposit memory deposit_ = IDepositFacet(bridge).getDeposit(lockHash_);
        assertGt(deposit_.expirationDate, 0);
        vm.warp(deposit_.expirationDate + 1);

        // Act
        vm.expectEmit(true, false, false, true);
        emit LogReclaimDeposit(lockHash_);
        vm.prank(_operator());
        IDepositFacet(bridge).reclaimDeposit(lockHash_);

        // Assert
        _validateDepositDeleted(lockHash_);
        // And
        assertEq(MockERC20(deposit_.token).balanceOf(deposit_.receiver), deposit_.amount);
    }

    function _validateDepositDeleted(uint256 lockHash_) internal {
        vm.expectRevert(abi.encodeWithSelector(IDepositFacet.DepositNotFoundError.selector));
        IDepositFacet.Deposit memory deposit_ = IDepositFacet(bridge).getDeposit(lockHash_);
    }
}