// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { WrappedToken } from "src/liquidityBridging/WrappedToken.sol";
import { IWrappedTokenFactory } from "src/liquidityBridging/interfaces/IWrappedTokenFactory.sol";

contract WrappedTokenFactory is IWrappedTokenFactory, Ownable {
    constructor() { }

    /// @inheritdoc IWrappedTokenFactory
    function createWrappedToken(uint16 srcChainId_, address token_, uint256 quantum_)
        external
        override
        onlyOwner
        returns (address wrappedToken_)
    {
        bytes memory bytecode_ = type(WrappedToken).creationCode;
        bytecode_ = abi.encodePacked(bytecode_, abi.encode(quantum_));
        bytes32 salt_ = keccak256(abi.encodePacked(srcChainId_, token_));

        assembly {
            wrappedToken_ := create2(0, add(bytecode_, 32), mload(bytecode_), salt_)
            if iszero(extcodesize(wrappedToken_)) { revert(0, 0) }
        }

        WrappedToken(wrappedToken_).transferOwnership(msg.sender);

        emit LogWrappedTokenCreated(quantum_);
    }
}
