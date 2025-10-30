// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Owned} from "solmate/src/auth/Owned.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ResolvedOrder, OutputToken} from "../base/ReactorStructs.sol";
import {IProtocolFeeController} from "../interfaces/IProtocolFeeController.sol";

/// @notice Mock protocol fee controller taking fee on input tokens
contract FeeControllerInputFees is IProtocolFeeController, Owned {
    error FeeOutOfRange();

    uint256 private constant BPS = 10_000;
    uint256 public defaultFeeBips = 5; // .05% default fee and max supported by base reactor
    address public immutable feeRecipient;

    /// @notice Custom per-token fee mapping (in basis points)
    mapping(ERC20 => uint256) public fees;

    constructor(address _owner, address _feeRecipient) Owned(_owner) {
        feeRecipient = _feeRecipient;
    }

    /// @inheritdoc IProtocolFeeController
    function getFeeOutputs(ResolvedOrder memory order)
        external
        view
        override
        returns (OutputToken[] memory result)
    {
        result = new OutputToken[](1);

        uint256 feeBips = fees[order.input.token];
        if (feeBips == 0) {
            // Use default fee if no specific override set
            feeBips = defaultFeeBips;
        }

        uint256 feeAmount = (order.input.amount * feeBips) / BPS;

        result[0] = OutputToken({
            token: address(order.input.token),
            amount: feeAmount,
            recipient: feeRecipient
        });
    }

    /// @notice Sets the default fee in basis points (max 10000 = 100%)
    function setDefaultFee(uint256 fee) external onlyOwner {
        if (fee >= BPS) revert FeeOutOfRange();
        defaultFeeBips = fee;
    }

    /// @notice Sets a custom fee for a specific input token
    function setFee(ERC20 tokenIn, uint256 fee) external onlyOwner {
        if (fee >= BPS) revert FeeOutOfRange();
        fees[tokenIn] = fee;
    }
}
