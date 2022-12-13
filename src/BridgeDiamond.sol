// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC165 } from "@openzeppelin/interfaces/IERC165.sol";

import { LibDiamond }  from "src/libraries/LibDiamond.sol";
import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";
import { AppStorage }  from "src/storage/AppStorage.sol";

contract BridgeDiamond {    

    AppStorage.AppStorage s;

    struct ConstructorArgs {
        address owner;
        address starkexOperatorAddress;
        address l1SetterAddress;
        address diamondCutFacet;
    }
    
    constructor(ConstructorArgs memory args_) {
        require(args_.owner != address(0), "BridgeDiamond: owner can't be address(0)");
        require(args_.starkexOperatorAddress != address(0), "BridgeDiamond: starkexOperatorAddress can't be address(0)");
        require(args_.l1SetterAddress != address(0), "BridgeDiamond: l1SetterAddress can't be address(0)");

        LibDiamond.setContractOwner(args_.owner);

        // Add the diamondCut external function from the diamondCutFacet
        IDiamondCut.FacetCut[] memory cut_ = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors_ = new bytes4[](1);
        functionSelectors_[0] = IDiamondCut.diamondCut.selector;
        cut_[0] = IDiamondCut.FacetCut({
            facetAddress: args_.diamondCutFacet, 
            action: IDiamondCut.FacetCutAction.Add, 
            functionSelectors: functionSelectors_
        });
        LibDiamond.diamondCut(cut_, address(0), "");   

        s.starkexOperatorAddress = args_.starkexOperatorAddress;
        s.l1SetterAddress = args_.l1SetterAddress;

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        // Add ERC165 interface support
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        //ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        //ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        //ds.supportedInterfaces[type(IERC173).interfaceId] = true;
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }
        // get facet from function selector
        address facet = address(bytes20(ds.facets[msg.sig]));
        require(facet != address(0), "BridgeDiamond: Function does not exist");
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }

    receive() external payable {
        revert("BridgeDiamond: Does not accept ether");
    }
}