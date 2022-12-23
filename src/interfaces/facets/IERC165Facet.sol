// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC165Facet {
    struct ERC165Storage {
        mapping(bytes4 => bool) supportedInterfaces;
    }

    /**
     * @notice Emits that the support for an interface has changed.
     * @param interfaceId The id of the interface.
     * @param flag Whether it was added or removed.
     */
    event LogSetSupportedInterface(bytes4 interfaceId, bool flag);

    /**
     * @notice Returns whether an interface is supported.
     * @param interfaceId_ The id of the interface.
     * @return The result
     */
    function supportsInterface(bytes4 interfaceId_) external view returns (bool);

    /**
     * @notice Changes the support for an interface.
     * @param interfaceId_ The id of the interface.
     * @param flag_ Whether it was added or removed.
     */
    function setSupportedInterface(bytes4 interfaceId_, bool flag_) external;
}
