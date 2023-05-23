// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";

library HelpersERC721 {
    /**
     * @notice Transfers a token from an address to another.
     * @param token_ The address of the token.
     * @param from_ The address that looses the token.
     * @param to_ The address that receives the token.
     * @param tokenId_ The id of the token.
     */
    function transferFrom(address token_, address from_, address to_, uint256 tokenId_) internal {
        uint256 size;
        assembly {
            size := extcodesize(token_)
        }
        require(size > 0, "HelpersERC721: Address has no code");
        (bool success, bytes memory result) =
            token_.call(abi.encodeWithSelector(IERC721.transferFrom.selector, from_, to_, tokenId_));
        handleReturn(success, result);
    }

    /**
     * @notice Handles the return value of a token transfer.
     * @dev If the call reverts, success_ is false and it reverts with the result_ (if not empty).
     *      If the call does not revert, but returns false in result_, it reverts.
     * @param success_ The result of the return value.
     * @param result_ The reason (in bytes) of the return value.
     */
    function handleReturn(bool success_, bytes memory result_) internal pure {
        if (success_) {
            if (result_.length > 0) {
                require(abi.decode(result_, (bool)), "HelpersERC721: contract call returned false");
            }
        } else {
            if (result_.length > 0) {
                /// Bubble up any reason for revert.
                revert(string(result_));
            } else {
                revert("HelpersERC721: contract call reverted");
            }
        }
    }
}
