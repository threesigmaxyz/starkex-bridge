//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/interfaces/IERC20.sol";
import { ECDSA } from "src/dependencies/ecdsa/ECDSA.sol";
import { HelpersECDSA } from "src/helpers/HelpersECDSA.sol";

import { MockERC20 } from "test/mocks/MockERC20.sol";
import { BaseFixture } from "test/fixtures/BaseFixture.sol";
import { Constants } from "src/constants/Constants.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { LibTokenRegister } from "src/libraries/LibTokenRegister.sol";
import { IWithdrawalFacet } from "src/interfaces/facets/IWithdrawalFacet.sol";
import { IStakerFacet } from "src/interfaces/facets/IStakerFacet.sol";
import { ILzTransmitter } from "src/liquidityBridging/interfaces/ILzTransmitter.sol";

contract StakerFacetTest is BaseFixture {
    uint256 internal constant STARK_KEY = 1234;

    event LogSetTransmitter(address indexed transmitter);
    event LogStakerMessageSent(bytes indexed payload, address indexed staker);

    //==============================================================================//
    //=== initialize Tests                                                       ===//
    //==============================================================================//

    function test_staker_initialize_ok() public {
        assertEq(IStakerFacet(_bridge).getTransmitter(), Constants.TRANSMITTER);
    }

    //==============================================================================//
    //=== setTransmitter Tests                                                   ===//
    //==============================================================================//

    function test_setTransmitter_ok(address transmitter_) public {
        // Arrange
        vm.expectEmit(true, false, false, true, _bridge);
        emit LogSetTransmitter(transmitter_);

        // Act
        vm.prank(_owner());
        IStakerFacet(_bridge).setTransmitter(transmitter_);

        // Assert
        assertEq(IStakerFacet(_bridge).getTransmitter(), transmitter_);
    }

    function test_setTransmitter_UnauthorizedError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(LibAccessControl.UnauthorizedError.selector));

        // Act + Assert
        vm.prank(_intruder());
        IStakerFacet(_bridge).setTransmitter(address(1));
    }

    //==============================================================================//
    //=== registerStaker Tests                                                   ===//
    //==============================================================================//

    function test_registerStaker_ok(
        uint256 starkKey_,
        uint256 vaultId_,
        uint256 amount_,
        uint256 fee_,
        uint256 feeSent_
    ) public {
        // Arrange
        vm.assume(starkKey_ < Constants.K_MODULUS && HelpersECDSA.isOnCurve(starkKey_));
        vm.assume(amount_ > 0);
        vm.assume(feeSent_ >= fee_);

        // Act + Assert
        _registerStaker(payable(_user()), starkKey_, vaultId_, address(_token), amount_, fee_, feeSent_);
    }

    function test_registerStaker_TokenNotRegisteredError() public {
        // Arrange
        address token_ = vm.addr(1);
        vm.label(token_, "token");
        vm.expectRevert(abi.encodeWithSelector(LibTokenRegister.TokenNotRegisteredError.selector, token_));

        // Act + Assert
        vm.prank(_user());
        IStakerFacet(_bridge).registerStaker{ value: 0 }(payable(_user()), STARK_KEY, 1, token_, 1);
    }

    function test_registerStaker_whenZeroStarkKey_InvalidStarkKeyError() public {
        // Arrange
        uint256 starkKey_ = 0;
        vm.expectRevert(abi.encodeWithSelector(IStakerFacet.InvalidStarkKeyError.selector));
        // And
        bytes memory payload_ = abi.encode(starkKey_, 1, address(_token), 2 / 2);
        vm.mockCall(
            Constants.TRANSMITTER,
            abi.encodeWithSelector(ILzTransmitter.getLayerZeroFee.selector, uint16(1), payload_),
            abi.encode(0, 0)
        );

        // Act + Assert
        vm.prank(_user());
        IStakerFacet(_bridge).registerStaker{ value: 0 }(payable(_user()), starkKey_, 1, address(_token), 2);
    }

    function test_registerStaker_whenLargerThanModulusStarkKey_InvalidStarkKeyError(uint256 starkKey_) public {
        // Arrange
        vm.assume(starkKey_ >= Constants.K_MODULUS);
        vm.expectRevert(abi.encodeWithSelector(IStakerFacet.InvalidStarkKeyError.selector));
        // And
        bytes memory payload_ = abi.encode(starkKey_, 1, address(_token), 2 / 2);
        vm.mockCall(
            Constants.TRANSMITTER,
            abi.encodeWithSelector(ILzTransmitter.getLayerZeroFee.selector, uint16(1), payload_),
            abi.encode(0, 0)
        );

        // Act + Assert
        vm.prank(_user());
        IStakerFacet(_bridge).registerStaker{ value: 0 }(payable(_user()), starkKey_, 1, address(_token), 2);
    }

    function test_registerStaker_whenNotInCurveStarkKey_InvalidStarkKeyError(uint256 starkKey_) public {
        // Arrange
        vm.assume(HelpersECDSA.isOnCurve(starkKey_) == false);
        vm.expectRevert(abi.encodeWithSelector(IStakerFacet.InvalidStarkKeyError.selector));
        // And
        bytes memory payload_ = abi.encode(starkKey_, 1, address(_token), 2 / 2);
        vm.mockCall(
            Constants.TRANSMITTER,
            abi.encodeWithSelector(ILzTransmitter.getLayerZeroFee.selector, uint16(1), payload_),
            abi.encode(0, 0)
        );

        // Act + Assert
        vm.prank(_user());
        IStakerFacet(_bridge).registerStaker{ value: 0 }(payable(_user()), starkKey_, 1, address(_token), 2);
    }

    function test_registerStaker_NotEnoughtFeeError(uint256 fee_, uint256 feeSent_) public {
        // Arrange
        vm.assume(feeSent_ < fee_);
        // And
        bytes memory payload_ = abi.encode(STARK_KEY, 1, address(_token), 2 / 2);
        vm.mockCall(
            Constants.TRANSMITTER,
            abi.encodeWithSelector(ILzTransmitter.getLayerZeroFee.selector, uint16(1), payload_),
            abi.encode(fee_, 0)
        );
        // And
        vm.expectRevert(abi.encodeWithSelector(IStakerFacet.NotEnoughtFeeError.selector));

        // Act + Assert
        vm.prank(_user());
        IStakerFacet(_bridge).registerStaker{ value: feeSent_ }(payable(_user()), STARK_KEY, 1, address(_token), 2);
    }

    function test_registerStaker_ZeroAmountError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(IStakerFacet.ZeroAmountError.selector));
        // And
        bytes memory payload_ = abi.encode(STARK_KEY, 1, address(_token), 0);
        vm.mockCall(
            Constants.TRANSMITTER,
            abi.encodeWithSelector(ILzTransmitter.getLayerZeroFee.selector, uint16(1), payload_),
            abi.encode(0, 0)
        );

        // Act + Assert
        vm.prank(_user());
        IStakerFacet(_bridge).registerStaker{ value: 0 }(payable(_user()), STARK_KEY, 1, address(_token), 0);
    }

    function test_registerStaker_ZeroAddressStakerError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(IStakerFacet.ZeroAddressStakerError.selector));
        // And
        bytes memory payload_ = abi.encode(STARK_KEY, 1, address(_token), 1);
        vm.mockCall(
            Constants.TRANSMITTER,
            abi.encodeWithSelector(ILzTransmitter.getLayerZeroFee.selector, uint16(1), payload_),
            abi.encode(0, 0)
        );

        // Act + Assert
        vm.prank(_user());
        IStakerFacet(_bridge).registerStaker{ value: 0 }(payable(address(0)), STARK_KEY, 1, address(_token), 2);
    }

    function test_registerStaker_HelpersErc20TransferFromError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(0x08c379a0, "ERC20: insufficient allowance"));
        // And
        bytes memory payload_ = abi.encode(STARK_KEY, 1, address(_token), 1);
        vm.mockCall(
            Constants.TRANSMITTER,
            abi.encodeWithSelector(ILzTransmitter.getLayerZeroFee.selector, uint16(1), payload_),
            abi.encode(0, 0)
        );
        // And
        vm.mockCall(
            Constants.TRANSMITTER,
            0,
            abi.encodeWithSelector(ILzTransmitter.keep.selector, uint16(1), payload_, _user()),
            abi.encode("")
        );

        // Act + Assert
        vm.prank(_user());
        IStakerFacet(_bridge).registerStaker{ value: 0 }(payable(_user()), STARK_KEY, 1, address(_token), 2);
    }

    //==============================================================================//
    //=== registerNativeStaker Tests                                             ===//
    //==============================================================================//

    function test_registerNativeStaker_ok(
        uint256 starkKey_,
        uint256 vaultId_,
        uint256 amount_,
        uint256 fee_,
        uint256 feeSent_
    ) public {
        // Arrange
        vm.assume(starkKey_ < Constants.K_MODULUS && HelpersECDSA.isOnCurve(starkKey_));
        vm.assume(amount_ > 0);
        vm.assume(amount_ < 100 ether);
        vm.assume(feeSent_ < 1 ether);
        vm.assume(feeSent_ >= fee_);

        // Act + Assert
        _registerStaker(payable(_user()), starkKey_, vaultId_, Constants.NATIVE, amount_, fee_, feeSent_);
    }

    function test_registerNativeStaker_NotEnoughtFeeError(uint256 fee_, uint256 feeSent_) public {
        // Arrange
        vm.assume(feeSent_ < 1 ether);
        vm.assume(feeSent_ < fee_);
        // And
        bytes memory payload_ = abi.encode(STARK_KEY, 1, Constants.NATIVE, 2 / 2);
        vm.mockCall(
            Constants.TRANSMITTER,
            abi.encodeWithSelector(ILzTransmitter.getLayerZeroFee.selector, uint16(1), payload_),
            abi.encode(fee_, 0)
        );
        // And
        vm.expectRevert(abi.encodeWithSelector(IStakerFacet.NotEnoughtFeeError.selector));

        // Act + Assert
        vm.prank(_user());
        IStakerFacet(_bridge).registerNativeStaker{ value: feeSent_ }(payable(_user()), STARK_KEY, 1, 2);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _registerStaker(
        address payable user_,
        uint256 starkKey_,
        uint256 vaultId_,
        address token_,
        uint256 amount_,
        uint256 fee_,
        uint256 feeSent_
    ) internal {
        bytes memory payload_ = abi.encode(starkKey_, vaultId_, token_, amount_ / 2);

        // Act + Assert
        if (token_ != Constants.NATIVE) {
            vm.prank(user_);
            MockERC20(token_).approve(_bridge, amount_);
        }
        // And
        vm.expectEmit(true, true, true, true);
        emit LogStakerMessageSent(payload_, user_);
        // And
        vm.mockCall(
            Constants.TRANSMITTER,
            abi.encodeWithSelector(ILzTransmitter.getLayerZeroFee.selector, uint16(1), payload_),
            abi.encode(fee_, 0)
        );
        // And
        vm.mockCall(
            Constants.TRANSMITTER,
            0,
            abi.encodeWithSelector(ILzTransmitter.keep.selector, uint16(1), payload_, user_),
            abi.encode("")
        );
        // And
        vm.prank(user_);
        token_ != Constants.NATIVE
            ? IStakerFacet(_bridge).registerStaker{ value: feeSent_ }(user_, starkKey_, vaultId_, token_, amount_)
            : IStakerFacet(_bridge).registerNativeStaker{ value: amount_ + feeSent_ }(user_, starkKey_, vaultId_, amount_);

        // Assert
        IStakerFacet.Staker memory staker_ = IStakerFacet(_bridge).getStakerInfo(user_, token_);
        assertEq(staker_.staker, user_);
        assertEq(staker_.starkKey, starkKey_);
        assertEq(staker_.vaultId, vaultId_);
        assertEq(staker_.token, token_);
        assertEq(staker_.amount, amount_ / 2);
        assertEq(staker_.amountLocked, amount_ / 2);
    }
}
