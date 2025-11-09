// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {SignedOrder} from "../base/ReactorStructs.sol";
import {IReactor} from "./IReactor.sol";

/// @notice Interface for order execution reactors
interface ITrustedReactor is IReactor {
    function MAX_SLIPPAGE_BPS() external view returns (uint256);
    function slippageBps() external view returns (uint256);
    function settleOrder(bytes32 orderId, uint256 returnedInputAmount) external;
}
