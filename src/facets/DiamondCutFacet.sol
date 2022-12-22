// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibDiamond }  from "src/libraries/LibDiamond.sol";
import { OnlyOwner } from "src/modifiers/OnlyOwner.sol";
import { IDiamondCut } from "src/interfaces/facets/IDiamondCut.sol";

/// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
/// The loupe functions are required by the EIP2535 Diamonds standard.
contract DiamondCutFacet is OnlyOwner, IDiamondCut {
    
    /// @inheritdoc IDiamondCut
    /// @dev Only callable by the owner.
    function diamondCut(
        FacetCut[] calldata diamondCut_,
        address init_,
        bytes calldata calldata_
    ) external override onlyOwner {
        LibDiamond.diamondCut(diamondCut_, init_, calldata_);
    }
}