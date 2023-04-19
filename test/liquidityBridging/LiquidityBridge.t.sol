// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { ILayerZeroEndpoint } from "src/dependencies/lz/interfaces/ILayerZeroEndpoint.sol";

import { LiquidityBridge } from "src/liquidityBridging/LiquidityBridge.sol";
import { WrappedToken } from "src/liquidityBridging/WrappedToken.sol";
import { IStarkEx } from "src/liquidityBridging/interfaces/IStarkEx.sol";
import { ILzReceptor } from "src/interfaces/interoperability/ILzReceptor.sol";
import { ILiquidityBridge } from "src/liquidityBridging/interfaces/ILiquidityBridge.sol";

contract LiquidityBridgeTest is Test {
    uint16 private constant MOCK_CHAIN_ID = 1337;
    uint16 private constant MOCK_QUANTUM = 10;
    bytes4 internal constant ERC20_SELECTOR = bytes4(keccak256("ERC20Token(address)"));
    uint256 internal constant MASK_250 = 0x03FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    LiquidityBridge private _liquidityBridge;
    address private _receptor = vm.addr(1);
    address private _starkEx = vm.addr(2);
    address private _tokenMock = vm.addr(3);
    address private _wrappedToken;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event LogSetStarkExAddress(address indexed starkEx);
    event LogDepositStarkEx(
        uint256 indexed starkKey, uint256 indexed vaultId, uint256 indexed assetType, uint256 amount
    );
    event LogAddWrappedToken(uint16 indexed srcChainId, address indexed token, address indexed wrappedToken);
    event LogTokenRegistedStarkEx(uint256 indexed assetType, bytes indexed assetInfo, uint256 quantum);

    function setUp() public {
        vm.label(_owner(), "owner");
        vm.label(_intruder(), "intruder");
        vm.label(_starkEx, "starkEx");
        vm.label(_receptor, "receptor");

        vm.etch(_starkEx, "Add Code or it reverts");
        vm.etch(_receptor, "Add Code or it reverts");

        _liquidityBridge = LiquidityBridge(_constructor(_owner(), _receptor, _starkEx));
        _wrappedToken = _deployWrappedToken(MOCK_CHAIN_ID, _tokenMock, MOCK_QUANTUM);
    }

    //==============================================================================//
    //=== constructor Tests                                                      ===//
    //==============================================================================//

    function test_constructor_ok(address receptor_, address starkEx_) public {
        vm.assume(receptor_ > address(0));
        vm.assume(starkEx_ > address(0));

        // Arrange
        vm.label(receptor_, "receptor");
        vm.label(starkEx_, "bridge");

        // Act + Assert
        _constructor(_owner(), receptor_, starkEx_);
    }

    function test_constructor_ZeroReceptorAddressError() public {
        // Arrange
        address receptor_ = address(0);
        vm.expectRevert(abi.encodeWithSelector(ILiquidityBridge.ZeroReceptorAddressError.selector));

        // Act + Assert
        new LiquidityBridge(_starkEx, receptor_);
    }

    function test_constructor_ZeroStarkExAddressError() public {
        // Arrange
        address starkEx_ = address(0);
        vm.expectRevert(abi.encodeWithSelector(ILiquidityBridge.ZeroStarkExAddressError.selector));

        // Act + Assert
        new LiquidityBridge(starkEx_, _receptor);
    }

    //==============================================================================//
    //=== deployAndRegisterWrappedToken Tests                                    ===//
    //==============================================================================//

    function test_deployAndRegisterWrappedToken_ok(uint16 chainId_, address token_, uint256 quantum_) public {
        // Arrange
        vm.assume(token_ > address(0));
        // And
        vm.mockCall(_starkEx, abi.encodeWithSelector(IStarkEx.registerToken.selector), abi.encode(""));
        // And
        address wrappedToken_ = _precompute_wrappedToken_address(chainId_, token_, quantum_);
        // And
        bytes memory assetInfo_ = abi.encodePacked(ERC20_SELECTOR, abi.encode(wrappedToken_));
        uint256 assetType_ = uint256(keccak256(abi.encodePacked(assetInfo_, quantum_))) & MASK_250;
        // And
        vm.expectEmit(true, true, true, true);
        emit LogAddWrappedToken(chainId_, token_, wrappedToken_);
        vm.expectEmit(true, true, true, true);
        emit LogTokenRegistedStarkEx(assetType_, assetInfo_, quantum_);

        // Act + Assert
        vm.prank(_owner());
        _liquidityBridge.deployAndRegisterWrappedToken(chainId_, token_, quantum_);
        assertEq(wrappedToken_, _liquidityBridge.getWrappedTokenAddress(chainId_, token_));
    }

    function test_deployAndRegisterWrappedToken_ZeroTokenAddressError() public {
        // Arrange
        address token_ = address(0);
        vm.expectRevert(abi.encodeWithSelector(ILiquidityBridge.ZeroTokenAddressError.selector));

        // Act
        vm.prank(_owner());
        _liquidityBridge.deployAndRegisterWrappedToken(1, token_, 1);
    }

    function test_deployAndRegisterWrappedToken_onlyOwner() public {
        // Arrange
        vm.expectRevert("Ownable: caller is not the owner");

        // Act + Assert
        vm.prank(_intruder());
        _liquidityBridge.deployAndRegisterWrappedToken(1, address(1), 1);
    }

    //==============================================================================//
    //=== mintAndDepositStarkEx Tests                                            ===//
    //==============================================================================//

    function test_mintAndDepositStarkEx_ok(uint256 starkKey_, uint256 vaultId_, uint256 amount_) public {
        // Arrange
        vm.assume(amount_ > 0);
        // And
        uint256 assetType_ = WrappedToken(_wrappedToken).getAssetType();
        vm.mockCall(
            _starkEx,
            abi.encodeWithSelector(IStarkEx.depositERC20.selector, starkKey_, assetType_, vaultId_, amount_),
            abi.encode("")
        );
        // And
        vm.expectEmit(true, true, true, true);
        emit LogDepositStarkEx(starkKey_, vaultId_, assetType_, amount_);

        // Act + Assert
        vm.prank(_receptor);
        _liquidityBridge.mintAndDepositStarkEx(MOCK_CHAIN_ID, starkKey_, vaultId_, _tokenMock, amount_);
    }

    function test_mintAndDepositStarkEx_NotReceptorError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(ILiquidityBridge.NotReceptorError.selector));

        // Act
        vm.prank(_intruder());
        _liquidityBridge.mintAndDepositStarkEx(MOCK_CHAIN_ID, 0, 0, _tokenMock, 0);
    }

    function test_mintAndDepositStarkEx_ZeroWrappedTokenError() public {
        // Arrange
        vm.expectRevert(abi.encodeWithSelector(ILiquidityBridge.ZeroWrappedTokenError.selector));

        // Act
        vm.prank(_receptor);
        _liquidityBridge.mintAndDepositStarkEx(0, 0, 0, _tokenMock, 0);
    }

    //==============================================================================//
    //=== Internal Test Helpers                                                  ===//
    //==============================================================================//

    function _constructor(address owner_, address receptor_, address starkEx_)
        internal
        returns (address liquidityBridge_)
    {
        // Arrange
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(address(0), owner_);
        vm.expectEmit(true, false, false, true);
        emit LogSetStarkExAddress(starkEx_);

        // Act + Assert
        vm.prank(owner_);
        liquidityBridge_ = address(new LiquidityBridge(starkEx_, receptor_));
    }

    function _deployWrappedToken(uint16 chainId_, address token_, uint256 quantum_) internal returns (address) {
        vm.mockCall(_starkEx, abi.encodeWithSelector(IStarkEx.registerToken.selector), abi.encode(""));

        vm.prank(_owner());
        _liquidityBridge.deployAndRegisterWrappedToken(chainId_, token_, quantum_);

        return _liquidityBridge.getWrappedTokenAddress(chainId_, token_);
    }

    function _precompute_wrappedToken_address(uint16 srcChainId_, address token_, uint256 quantum_)
        internal
        view
        returns (address)
    {
        address factory_ = _liquidityBridge.getFactoryAddress();

        bytes memory bytecode_ = type(WrappedToken).creationCode;

        bytecode_ = abi.encodePacked(bytecode_, abi.encode(quantum_));

        bytes32 salt_ = keccak256(abi.encodePacked(srcChainId_, token_));

        bytes32 hash_ = keccak256(abi.encodePacked(bytes1(0xff), factory_, salt_, keccak256(bytecode_)));

        return address(uint160(uint256(hash_)));
    }

    function _owner() internal pure returns (address) {
        return vm.addr(1337);
    }

    function _intruder() internal pure returns (address) {
        return vm.addr(999);
    }
}
