// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Constants } from "src/constants/Constants.sol";

library HelpersECDSA {
    function isOnCurve(uint256 starkKey_) internal view returns (bool) {
        uint256 xCubed_ = mulmod(mulmod(starkKey_, starkKey_, Constants.K_MODULUS), starkKey_, Constants.K_MODULUS);
        return isQuadraticResidue(addmod(addmod(xCubed_, starkKey_, Constants.K_MODULUS), Constants.K_BETA, Constants.K_MODULUS));
    }

    function isQuadraticResidue(uint256 fieldElement_) internal view returns (bool) {
        return 1 == fieldPow(fieldElement_, ((Constants.K_MODULUS - 1) / 2));
    }

	function fieldPow(uint256 base, uint256 exponent) internal view returns (uint256) {
        (bool success, bytes memory returndata) = address(5).staticcall(
            abi.encode(0x20, 0x20, 0x20, base, exponent, Constants.K_MODULUS)
        );
        require(success, string(returndata));
        return abi.decode(returndata, (uint256));
    }
}