// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { HelpersERC20 } from "src/helpers/HelpersERC20.sol";
import { Constants } from "src/constants/Constants.sol";

library HelpersTransferNativeOrERC20 {
    error NativeTransferFailedError(string reason);

    // Reentrant. Use checks-effects-interactions pattern.
    function transfer(address token_, address receiver_, uint256 amount_) internal {
        if (token_ != Constants.NATIVE) {
            HelpersERC20.transfer(token_, receiver_, amount_);
        } else {
            (bool success, bytes memory reason) = receiver_.call{ value: amount_ }("");
            if (!success) revert NativeTransferFailedError(string(reason));
        }
    }
}
