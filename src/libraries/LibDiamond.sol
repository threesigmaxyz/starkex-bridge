// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IDiamondCut } from "src/interfaces/facets/IDiamondCut.sol";

library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    bytes32 constant CLEAR_ADDRESS_MASK = bytes32(uint256(0xffffffffffffffffffffffff));
    bytes32 constant CLEAR_SELECTOR_MASK = bytes32(uint256(0xffffffff << 224));

    struct DiamondStorage {
        /// maps function selectors to the facets that execute the functions.
        /// and maps the selectors to their position in the selectorSlots array.
        /// func selector => address facet, selector position
        mapping(bytes4 => bytes32) facets;
        /// array of slots of function selectors.
        /// each slot holds 8 function selectors.
        mapping(uint256 => bytes32) selectorSlots;
        /// The number of function selectors in selectorSlots
        uint16 selectorCount;
    }

    error InitializationFunctionReverted(address initializationContractAddress, bytes cdata);
    error NotContractError(string errorMessage);

    event DiamondCut(IDiamondCut.FacetCut[] diamondCut, address init, bytes cdata);

    /// @dev Storage of this facet using diamond storage.
    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position_ = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position_
        }
    }

    /**
     * @notice DIAMOND CUT
     *         Internal function version of diamondCut
     *         This code is almost the same as the external diamondCut,
     *         except it is using 'Facet[] memory _diamondCut' instead of
     *         'Facet[] calldata _diamondCut'.
     *         The code is duplicated to prevent copying calldata to memory which
     *         causes an error for a two dimensional array.
     * @param _diamondCut The address and selectors of a facet.
     * @param init_ The address of the initialization function to call.
     * @param calldata_ The name and arguments of the initialization function.
     */
    function diamondCut(IDiamondCut.FacetCut[] memory _diamondCut, address init_, bytes memory calldata_) internal {
        DiamondStorage storage ds = diamondStorage();
        uint256 originalSelectorCount = ds.selectorCount;
        uint256 selectorCount = originalSelectorCount;
        bytes32 selectorSlot;
        // Check if last selector slot is not full
        // "selectorCount & 7" is a gas efficient modulo by eight "selectorCount % 8"
        if (selectorCount & 7 > 0) {
            /// get last selectorSlot
            /// "selectorSlot >> 3" is a gas efficient division by 8 "selectorSlot / 8"
            selectorSlot = ds.selectorSlots[selectorCount >> 3];
        }
        // loop through diamond cut
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            (selectorCount, selectorSlot) = addReplaceRemoveFacetSelectors(
                selectorCount,
                selectorSlot,
                _diamondCut[facetIndex].facetAddress,
                _diamondCut[facetIndex].action,
                _diamondCut[facetIndex].functionSelectors
            );
        }
        if (selectorCount != originalSelectorCount) {
            ds.selectorCount = uint16(selectorCount);
        }
        // If last selector slot is not full
        // "selectorCount & 7" is a gas efficient modulo by eight "selectorCount % 8"
        if (selectorCount & 7 > 0) {
            // "selectorSlot >> 3" is a gas efficient division by 8 "selectorSlot / 8"
            ds.selectorSlots[selectorCount >> 3] = selectorSlot;
        }
        emit DiamondCut(_diamondCut, init_, calldata_);
        initializeDiamondCut(init_, calldata_);
    }

    /**
     * @notice Adds, replaces or removes facet selectors.
     * @param selectorCount_ The number of selectors.
     * @param selectorSlot_ The position in storage to store the selector.
     * @param newFacetAddress_ The address of the new facet.
     * @param selectors_ The selectors to change.
     */
    function addReplaceRemoveFacetSelectors(
        uint256 selectorCount_,
        bytes32 selectorSlot_,
        address newFacetAddress_,
        IDiamondCut.FacetCutAction action_,
        bytes4[] memory selectors_
    ) internal returns (uint256, bytes32) {
        DiamondStorage storage ds = diamondStorage();
        require(selectors_.length > 0, "LibDiamondCut: No selectors in facet to cut");
        if (action_ == IDiamondCut.FacetCutAction.Add) {
            enforceHasContractCode(newFacetAddress_, "LibDiamondCut: Add facet has no code");
            for (uint256 selectorIndex; selectorIndex < selectors_.length; selectorIndex++) {
                bytes4 selector = selectors_[selectorIndex];
                bytes32 oldFacet = ds.facets[selector];
                require(
                    address(bytes20(oldFacet)) == address(0), "LibDiamondCut: Can't add function that already exists"
                );
                // add facet for selector
                ds.facets[selector] = bytes20(newFacetAddress_) | bytes32(selectorCount_);
                // "selectorCount_ & 7" is a gas efficient modulo by eight "selectorCount_ % 8"
                // " << 5 is the same as multiplying by 32 ( * 32)
                uint256 selectorInSlotPosition = (selectorCount_ & 7) << 5;
                // clear selector position in slot and add selector
                selectorSlot_ = (selectorSlot_ & ~(CLEAR_SELECTOR_MASK >> selectorInSlotPosition))
                    | (bytes32(selector) >> selectorInSlotPosition);
                // if slot is full then write it to storage
                if (selectorInSlotPosition == 224) {
                    // "selectorSlot_ >> 3" is a gas efficient division by 8 "selectorSlot_ / 8"
                    ds.selectorSlots[selectorCount_ >> 3] = selectorSlot_;
                    selectorSlot_ = 0;
                }
                selectorCount_++;
            }
        } else if (action_ == IDiamondCut.FacetCutAction.Replace) {
            enforceHasContractCode(newFacetAddress_, "LibDiamondCut: Replace facet has no code");
            for (uint256 selectorIndex; selectorIndex < selectors_.length; selectorIndex++) {
                bytes4 selector = selectors_[selectorIndex];
                bytes32 oldFacet = ds.facets[selector];
                address oldFacetAddress = address(bytes20(oldFacet));
                // only useful if immutable functions exist
                require(oldFacetAddress != address(this), "LibDiamondCut: Can't replace immutable function");
                require(oldFacetAddress != newFacetAddress_, "LibDiamondCut: Can't replace function with same function");
                require(oldFacetAddress != address(0), "LibDiamondCut: Can't replace function that doesn't exist");
                // replace old facet address
                ds.facets[selector] = (oldFacet & CLEAR_ADDRESS_MASK) | bytes20(newFacetAddress_);
            }
        } else if (action_ == IDiamondCut.FacetCutAction.Remove) {
            require(newFacetAddress_ == address(0), "LibDiamondCut: Remove facet address must be address(0)");
            // "selectorCount_ >> 3" is a gas efficient division by 8 "selectorCount_ / 8"
            uint256 selectorSlotCount = selectorCount_ >> 3;
            // "selectorCount_ & 7" is a gas efficient modulo by eight "selectorCount_ % 8"
            uint256 selectorInSlotIndex = selectorCount_ & 7;
            for (uint256 selectorIndex; selectorIndex < selectors_.length; selectorIndex++) {
                if (selectorSlot_ == 0) {
                    // get last selectorSlot
                    selectorSlotCount--;
                    selectorSlot_ = ds.selectorSlots[selectorSlotCount];
                    selectorInSlotIndex = 7;
                } else {
                    selectorInSlotIndex--;
                }
                bytes4 lastSelector;
                uint256 oldSelectorsSlotCount;
                uint256 oldSelectorInSlotPosition;
                // adding a block here prevents stack too deep error
                {
                    bytes4 selector = selectors_[selectorIndex];
                    bytes32 oldFacet = ds.facets[selector];
                    require(
                        address(bytes20(oldFacet)) != address(0),
                        "LibDiamondCut: Can't remove function that doesn't exist"
                    );
                    // only useful if immutable functions exist
                    require(
                        address(bytes20(oldFacet)) != address(this), "LibDiamondCut: Can't remove immutable function"
                    );
                    // replace selector with last selector in ds.facets
                    // gets the last selector
                    // " << 5 is the same as multiplying by 32 ( * 32)
                    lastSelector = bytes4(selectorSlot_ << (selectorInSlotIndex << 5));
                    if (lastSelector != selector) {
                        /// update last selector slot position info
                        ds.facets[lastSelector] = (oldFacet & CLEAR_ADDRESS_MASK) | bytes20(ds.facets[lastSelector]);
                    }
                    delete ds.facets[selector];
                    uint256 oldSelectorCount = uint16(uint256(oldFacet));
                    // "oldSelectorCount >> 3" is a gas efficient division by 8 "oldSelectorCount / 8"
                    oldSelectorsSlotCount = oldSelectorCount >> 3;
                    // "oldSelectorCount & 7" is a gas efficient modulo by eight "oldSelectorCount % 8"
                    // " << 5 is the same as multiplying by 32 ( * 32)
                    oldSelectorInSlotPosition = (oldSelectorCount & 7) << 5;
                }
                if (oldSelectorsSlotCount != selectorSlotCount) {
                    bytes32 oldSelectorSlot = ds.selectorSlots[oldSelectorsSlotCount];
                    // clears the selector we are deleting and puts the last selector in its place.
                    oldSelectorSlot = (oldSelectorSlot & ~(CLEAR_SELECTOR_MASK >> oldSelectorInSlotPosition))
                        | (bytes32(lastSelector) >> oldSelectorInSlotPosition);
                    // update storage with the modified slot
                    ds.selectorSlots[oldSelectorsSlotCount] = oldSelectorSlot;
                } else {
                    // clears the selector we are deleting and puts the last selector in its place.
                    selectorSlot_ = (selectorSlot_ & ~(CLEAR_SELECTOR_MASK >> oldSelectorInSlotPosition))
                        | (bytes32(lastSelector) >> oldSelectorInSlotPosition);
                }
                if (selectorInSlotIndex == 0) {
                    delete ds.selectorSlots[selectorSlotCount];
                    selectorSlot_ = 0;
                }
            }
            selectorCount_ = selectorSlotCount * 8 + selectorInSlotIndex;
        } else {
            revert("LibDiamondCut: Incorrect FacetCutAction");
        }
        return (selectorCount_, selectorSlot_);
    }

    /**
     * @notice Initializes the diamond cut in the address init_ with the function in calldata_.
     * @param init_ The address of the contract.
     * @param calldata_ The name and arguments of the function.
     */
    function initializeDiamondCut(address init_, bytes memory calldata_) internal {
        if (init_ == address(0)) {
            return;
        }
        enforceHasContractCode(init_, "LibDiamondCut: init_ address has no code");
        (bool success_, bytes memory error_) = init_.delegatecall(calldata_);
        if (!success_) {
            if (error_.length > 0) {
                // bubble up error
                // @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error_)
                    revert(add(32, error_), returndata_size)
                }
            } else {
                revert InitializationFunctionReverted(init_, calldata_);
            }
        }
    }

    /**
     * @notice Reverts if the address contract_ has no code.
     * @param contract_ The address to check.
     * @param errorMessage_ The error message to revert.
     */
    function enforceHasContractCode(address contract_, string memory errorMessage_) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(contract_)
        }
        if (contractSize == 0) revert NotContractError(errorMessage_);
    }
}
