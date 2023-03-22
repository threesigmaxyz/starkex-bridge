// contracts/Messages.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import { IRelayProvider } from "src/dependencies/wormhole/interfaces/IRelayProvider.sol";

interface ICoreRelayer {
    /**
     * @dev This is the basic function for requesting delivery
     */
    function requestDelivery(DeliveryRequest memory request, uint32 nonce, IRelayProvider provider)
        external
        payable
        returns (uint64 sequence);

    function getDefaultRelayProvider() external returns (IRelayProvider);

    function getDefaultRelayParams() external pure returns (bytes memory relayParams);

    function quoteGasDeliveryFee(uint16 targetChain, uint32 gasLimit, IRelayProvider relayProvider)
        external
        pure
        returns (uint256 deliveryQuote);

    function quoteApplicationBudgetFee(uint16 targetChain, uint256 targetAmount, IRelayProvider provider)
        external
        pure
        returns (uint256 nativeQuote);

    struct DeliveryRequest {
        uint16 targetChain;
        bytes32 targetAddress;
        bytes32 refundAddress;
        uint256 computeBudget;
        uint256 applicationBudget;
        bytes relayParameters; //Optional
    }
}
