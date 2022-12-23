// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibDiamond } from "src/libraries/LibDiamond.sol";
import { LibAccessControl } from "src/libraries/LibAccessControl.sol";
import { IDiamondCut } from "src/interfaces/facets/IDiamondCut.sol";

contract BridgeDiamond {
    error ZeroAddressOwnerError();
    error FunctionDoesNotExistError();
    error EtherReceivedError();

    constructor(address owner_, address diamondCutFacet_) {
        if (owner_ == address(0)) revert ZeroAddressOwnerError();

        LibAccessControl.accessControlStorage().roles[LibAccessControl.OWNER_ROLE] = owner_;

        /// Add the diamondCut external function from the diamondCutFacet
        IDiamondCut.FacetCut[] memory cut_ = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors_ = new bytes4[](1);
        functionSelectors_[0] = IDiamondCut.diamondCut.selector;
        cut_[0] = IDiamondCut.FacetCut({
            facetAddress: diamondCutFacet_,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors_
        });
        LibDiamond.diamondCut(cut_, address(0), "");
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }
        // get facet from function selector
        address facet = address(bytes20(ds.facets[msg.sig]));
        if (facet == address(0)) revert FunctionDoesNotExistError();
        // Execute external function from facet using delegatecall and return any value
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {
        revert EtherReceivedError();
    }
}
