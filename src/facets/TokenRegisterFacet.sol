// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibTokenRegister }    from "src/libraries/LibTokenRegister.sol";

import { ITokenRegisterFacet } from "src/interfaces/ITokenRegisterFacet.sol";
import { AppStorage }          from "src/storage/AppStorage.sol";

contract TokenRegisterFacet is ITokenRegisterFacet {
    
    uint256 internal constant MASK_250 = 0x03FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 constant QUANTUM_LOWER_BOUND = 0;
    uint256 constant QUANTUM_UPPER_BOUND = 2**128;
    uint256 constant K_MODULUS = 0x800000000000011000000000000000000000000000000000000000000000001;

    bytes4 internal constant ETH_SELECTOR = bytes4(keccak256("ETH()"));
    bytes4 internal constant ERC20_SELECTOR = bytes4(keccak256("ERC20Token(address)"));
    bytes4 internal constant ERC721_SELECTOR = bytes4(keccak256("ERC721Token(address,uint256)"));
    bytes4 internal constant ERC1155_SELECTOR = bytes4(keccak256("ERC1155Token(address,uint256)"));
    bytes4 internal constant MINTABLE_ERC20_SELECTOR = bytes4(keccak256("MintableERC20Token(address)"));
    bytes4 internal constant MINTABLE_ERC721_SELECTOR = bytes4(keccak256("MintableERC721Token(address,uint256)"));

    // The selector follows the 0x20 bytes assetInfo.length field.
    uint256 internal constant SELECTOR_OFFSET = 0x20;
    uint256 internal constant SELECTOR_SIZE = 4;
    uint256 internal constant TOKEN_CONTRACT_ADDRESS_OFFSET = SELECTOR_OFFSET + SELECTOR_SIZE;

    AppStorage.AppStorage s;

    modifier onlyTokensAdmin() {
        require(LibTokenRegister.isTokenAdmin(msg.sender), "ONLY_TOKENS_ADMIN"); // TODO custom error
        _;
    }

    function setValidTokenAdmin(address admin_, bool isValid_) external override { // TODO onlyGovernance {
        LibTokenRegister.tokenRegisterStorage().tokenAdmins[admin_] = isValid_;
        emit LogTokenAdminSet(admin_, isValid_);
    }

    function registerToken(
        uint256 assetType_,
        bytes calldata assetInfo_,
        uint256 quantum_
    ) public override onlyTokensAdmin {
        // Make sure it is not invalid or already registered.
        require(!LibTokenRegister.isAssetRegistered(assetType_), "ASSET_ALREADY_REGISTERED");
        require(assetType_ < K_MODULUS, "INVALID_ASSET_TYPE");
        require(quantum_ > QUANTUM_LOWER_BOUND, "INVALID_QUANTUM");
        require(quantum_ < QUANTUM_UPPER_BOUND, "INVALID_QUANTUM");

        // Require that the assetType is the hash of the assetInfo and quantum truncated to 250 bits.
        uint256 enforcedId_ = uint256(keccak256(abi.encodePacked(assetInfo_, quantum_))) & MASK_250;
        require(assetType_ == enforcedId_, "INVALID_ASSET_TYPE_2");
        require(isFungibleAssetInfo(assetInfo_), "INVALID_ASSET_TYPE_3"); // TODO only ERC20

        address tokenAddress_ = extractContractAddressFromAssetInfo(assetInfo_);
        // TODO? require(tokenAddress_.isContract(), "BAD_TOKEN_ADDRESS");

        // Add token to the in-storage structures.
        LibTokenRegister.TokenRegisterStorage storage fs = LibTokenRegister.tokenRegisterStorage();
        fs.registeredAssetType[assetType_] = true;
        fs.assetTypeToAssetInfo[assetType_] = assetInfo_;
        fs.assetTypeToQuantum[assetType_] = quantum_;
        fs.registeredToken[tokenAddress_] = true;   // TODO can clash when multiple quantums are used

        // Log the registration of a new token.
        emit LogTokenRegistered(assetType_, assetInfo_, quantum_);
    }

    /*
        Extract the tokenSelector from assetInfo.
        Works like bytes4 tokenSelector = abi.decode(assetInfo, (bytes4))
        but does not revert when assetInfo.length < SELECTOR_OFFSET.
    */
    function extractTokenSelectorFromAssetInfo(bytes memory assetInfo_) private pure returns (bytes4 selector_) {
        assembly {
            selector_ := and(
                0xffffffff00000000000000000000000000000000000000000000000000000000,
                mload(add(assetInfo_, SELECTOR_OFFSET))
            )
        }
    }

    function isFungibleAssetInfo(bytes memory assetInfo_) private view returns (bool) {
        bytes4 tokenSelector_ = extractTokenSelectorFromAssetInfo(assetInfo_);
        return (
            tokenSelector_ == ETH_SELECTOR ||
            tokenSelector_ == ERC20_SELECTOR ||
            tokenSelector_ == MINTABLE_ERC20_SELECTOR
        );
    }

    function extractContractAddressFromAssetInfo(bytes memory assetInfo_) private pure returns (address) {
        uint256 offset_ = TOKEN_CONTRACT_ADDRESS_OFFSET;
        uint256 res_;
        assembly {
            res_ := mload(add(assetInfo_, offset_))
        }
        return address(uint160(res_));
    }

}