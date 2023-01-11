// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { OnlyOwner } from "src/modifiers/OnlyOwner.sol";
import { IERC165Facet } from "src/interfaces/facets/IERC165Facet.sol";

contract ERC165Facet is OnlyOwner, IERC165Facet {
    bytes32 constant ERC165_STORAGE_POSITION = keccak256("ERC165_STORAGE_POSITION");

    /// @dev Storage of this facet using diamond storage.
    function erc165Storage() internal pure returns (ERC165Storage storage erc165s) {
        bytes32 position_ = ERC165_STORAGE_POSITION;
        assembly {
            erc165s.slot := position_
        }
    }

    /// @inheritdoc IERC165Facet
    function supportsInterface(bytes4 interfaceId_) external view override returns (bool) {
        return erc165Storage().supportedInterfaces[interfaceId_];
    }

    /// @inheritdoc IERC165Facet
    function setSupportedInterface(bytes4 interfaceId_, bool flag_) external override onlyOwner {
        erc165Storage().supportedInterfaces[interfaceId_] = flag_;
        emit LogSetSupportedInterface(interfaceId_, flag_);
    }
}
