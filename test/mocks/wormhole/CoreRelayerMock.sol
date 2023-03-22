// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ICoreRelayer } from "src/dependencies/wormhole/interfaces/ICoreRelayer.sol";
import { IRelayProvider } from "src/dependencies/wormhole/interfaces/IRelayProvider.sol";

contract CoreRelayerMock is ICoreRelayer {
    IRelayProvider private immutable _relayprovider;

    constructor(address provider_) {
        _relayprovider = IRelayProvider(provider_);
    }

    function requestDelivery(DeliveryRequest memory, uint32, IRelayProvider)
        external
        payable
        override
        returns (uint64 sequence)
    {
        return 0;
    }

    function getDefaultRelayParams() external pure override returns (bytes memory relayParams) {
        return bytes("");
    }

    function getDefaultRelayProvider() external view override returns (IRelayProvider) {
        return _relayprovider;
    }

    function quoteGasDeliveryFee(uint16, uint32, IRelayProvider)
        external
        pure
        override
        returns (uint256 deliveryQuote)
    {
        return 0;
    }

    function quoteApplicationBudgetFee(uint16, uint256, IRelayProvider)
        external
        pure
        override
        returns (uint256 nativeQuote)
    {
        return 0;
    }
}
