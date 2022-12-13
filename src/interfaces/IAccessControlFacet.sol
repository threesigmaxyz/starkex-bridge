// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Interface for contract ownership management.
/// @dev Follows the ERC-173 Contract Ownership Standard.
interface IAccessControlFacet {
    //==============================================================================//
    //=== Events                                                                 ===//
    //==============================================================================//
    
    /// @dev This emits when ownership of a contract changes.
    /// @param previousOwner The previous contract owner.
    /// @param newOwner The new contract owner.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event LogSetStarkExOperator(address operator);
    event LogSetInteroperabilityContract(address interop);

    //==============================================================================//
    //=== Setters                                                                ===//
    //==============================================================================//
    
    /// @notice Sets the address of the new owner of the contract.
    /// @dev Set to `address(0)` to renounce any ownership.
    /// @param owner_ The address of the new owner of the contract
    function transferOwnership(address owner_) external;

    /// @notice Sets the StarkEx operator
    /// @dev The StarkEx operator is the address that has the authority to call certain
    /// functions that affect the entire StarkEx system.
    /// @param operator_ The address of the StarkEx operator
    function setStarkExOperator(address operator_) external;

    /// @notice Sets the interoperability contract address
    /// @dev This function sets the interoperability contract address
    /// @param interop_ The address of the interoperability contract
    function setInteroperabilityContract(address interop_) external;

    //==============================================================================//
    //=== Getters                                                                ===//
    //==============================================================================//

    /// @notice Gets the address of the owner
    /// @return owner_ The address of the owner.
    function owner() external view returns (address owner_);

    /// @notice TODO
    /// @return operator_ TODO
    function getStarkExOperator() external returns (address operator_);

    /// @notice TODO
    /// @return interop_ TODO
    function getInteroperabilityContract() external returns (address interop_);
}