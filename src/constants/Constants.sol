//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Constants {
    uint256 constant DEPOSIT_OFFCHAIN_EXPIRATION_TIMEOUT = 5000; // TODO
    uint256 constant DEPOSIT_ONCHAIN_EXPIRATION_TIMEOUT = 7200; // TODO

    uint256 constant WITHDRAWAL_ONCHAIN_EXPIRATION_TIMEOUT = 5000; // TODO

    /// STARK constants.
    uint256 constant K_MODULUS = 0x800000000000011000000000000000000000000000000000000000000000001;
    uint256 constant K_BETA = 0x6f21413efbe40de150e596d72f7a8c5609ad26c15c915c1f4cdfcb99cee9e89;

    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
}
