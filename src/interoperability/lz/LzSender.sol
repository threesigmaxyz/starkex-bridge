// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ILzSender } from "src/interfaces/interoperability/lz/ILzSender.sol";
import { LzBase }      from "src/interoperability/lz/LzBase.sol";

abstract contract LzSender is ILzSender, LzBase {

    /// @notice Minimum destination chain gas.
    mapping(uint16 => mapping(uint16 => uint)) public minDstGasLookup;

    constructor(address _endpoint) LzBase(_endpoint) {}

    /**
     * @notice Sends the payload to the lzEndpoint if the trusted remote is set.
     * @param dstChainId_ The id of the destination chain.
     * @param payload_ The payload of the message.
     * @param refundAddress_ The address to send the refund of the unspent gas.
     * @param zeroPaymentAddress_ Set to 0.
     * @param adapterParams_ Specifies parameters such as the gas limit to use in the destination chain.
     * @param nativeFee_ Ether value to send to process the message.
     */
    function _lzSend(
        uint16 dstChainId_,
        bytes memory payload_,
        address payable refundAddress_,
        address zeroPaymentAddress_,
        bytes memory adapterParams_,
        uint256 nativeFee_
    ) internal virtual {
        bytes memory trustedRemote = trustedRemoteLookup[dstChainId_];
        if (trustedRemote.length == 0) revert RemoteChainNotTrustedError();

        lzEndpoint.send{value: nativeFee_}(
            dstChainId_,
            trustedRemote,
            payload_,
            refundAddress_,
            zeroPaymentAddress_,
            adapterParams_
        );
    }

    /**
     * @notice Checks the gas limit of a chain.
     * @param dstChainId_ The id of the destination chain.
     * @param packetType_ The type of the packet to send.
     * @param adapterParams_ Specifies parameters such as the gas limit to use in the destination chain.
     * @param extraGas_ Extra gas to send.
     */
    function _checkGasLimit(
        uint16 dstChainId_,
        uint16 packetType_,
        bytes memory adapterParams_,
        uint256 extraGas_
    ) internal view virtual {
        uint providedGasLimit = _getGasLimit(adapterParams_);
        uint minGasLimit = minDstGasLookup[dstChainId_][packetType_] + extraGas_;
        if (minGasLimit == 0) revert ZeroGasLimitError();
        if (providedGasLimit < minGasLimit) revert GasLimitToolowError();
    }

    /**
     * @notice Checks the gas limit in the adapterParams_.
     * @param adapterParams_ Specifies parameters such as the gas limit to use in the destination chain.
     * @return gasLimit The gas limit.
     */
    function _getGasLimit(bytes memory adapterParams_) internal pure virtual returns (uint gasLimit) {
        if (adapterParams_.length < 34) revert InvalidAdapterParamsError();
        assembly {
            gasLimit := mload(add(adapterParams_, 34))
        }
    }

    /// @inheritdoc ILzSender
    function setSendVersion(uint16 version_) external override onlyOwner {
        lzEndpoint.setSendVersion(version_);
    }

    /// @inheritdoc ILzSender
    function setMinDstGas(uint16 dstChainId_, uint16 packetType_, uint minGas_) external override onlyOwner {
        if (minGas_ == 0) revert ZeroGasLimitError();
        minDstGasLookup[dstChainId_][packetType_] = minGas_;
        emit LogSetMinDstGas(dstChainId_, packetType_, minGas_);
    }
}