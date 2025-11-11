// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ReactorEvents} from "../base/ReactorEvents.sol";
import {ResolvedOrderLib} from "../lib/ResolvedOrderLib.sol";
import {CurrencyLibrary} from "../lib/CurrencyLibrary.sol";
import {IReactorCallback} from "../interfaces/IReactorCallback.sol";
import {ITrustedReactor} from "../interfaces/ITrustedReactor.sol";
import {ProtocolFees} from "../base/ProtocolFees.sol";
import {SignedOrder, ResolvedOrder, OutputToken, PendingOrder} from "../base/ReactorStructs.sol";

/// @notice Generic reactor logic for settling off-chain signed orders
///     using arbitrary fill methods specified by a filler
abstract contract TrustedBaseReactor is ITrustedReactor, ReactorEvents, ProtocolFees, ReentrancyGuard {
    using SafeTransferLib for ERC20;
    using ResolvedOrderLib for ResolvedOrder;
    using CurrencyLibrary for address;

    error PendingOrderAlreadyExists();
    error OrderDoesNotExist();
    error InsufficientAmount();
    error InvalidSlippageAmount();
    error CallerNotWhitelisted();

    event WhitelistUpdated(address indexed account, bool isWhitelisted);
    event OrderDeferred(bytes32 indexed orderId, address indexed executor, address indexed swapper, address inputToken, uint256 inputAmount);
    event OrderSettled(bytes32 indexed orderId, bool returnInput);
    event SlippageUpdated(uint256 bps);

    uint256 public constant MAX_SLIPPAGE_BPS = 10_000;
    uint256 public constant SLIPPAGE_UB = 1000;
    uint256 public slippageBps = 200;

    /// @notice permit2 address used for token transfers and signature verification
    IPermit2 public immutable permit2;
    
    mapping(address => bool) public whitelist;
    mapping(bytes32 => PendingOrder) private _pendingOrders;


    modifier onlyWhitelistedCaller() {
        if(!whitelist[msg.sender]) {
            revert CallerNotWhitelisted();
        }
        _;
    }

    constructor(IPermit2 _permit2, address _protocolFeeOwner) ProtocolFees(_protocolFeeOwner) {
        permit2 = _permit2;
    }   

    function setSlippageBps(uint256 bps) external onlyOwner {

        if(bps > SLIPPAGE_UB) {
            revert InvalidSlippageAmount();
        }

        slippageBps = bps;
        emit SlippageUpdated(bps);
    }

    function setWhitelist(address account, bool isWhitelisted) external onlyOwner {
        whitelist[account] = isWhitelisted;
        emit WhitelistUpdated(account, isWhitelisted);
    }

    function execute(SignedOrder calldata order) external payable override nonReentrant onlyWhitelistedCaller {
        ResolvedOrder[] memory resolvedOrders = new ResolvedOrder[](1);
        resolvedOrders[0] = _resolve(order);

        _prepare(resolvedOrders);
        _createPendingOrders(resolvedOrders);
    }

    function executeWithCallback(SignedOrder calldata order, bytes calldata callbackData)
        external
        payable
        override
        nonReentrant
        onlyWhitelistedCaller
    {
        ResolvedOrder[] memory resolvedOrders = new ResolvedOrder[](1);
        resolvedOrders[0] = _resolve(order);

        _prepare(resolvedOrders);
        IReactorCallback(msg.sender).reactorCallback(resolvedOrders, callbackData);
        _createPendingOrders(resolvedOrders);
    }

    function executeBatch(SignedOrder[] calldata orders) external payable override nonReentrant onlyWhitelistedCaller {
        uint256 ordersLength = orders.length;
        ResolvedOrder[] memory resolvedOrders = new ResolvedOrder[](ordersLength);

        unchecked {
            for (uint256 i = 0; i < ordersLength; i++) {
                resolvedOrders[i] = _resolve(orders[i]);
            }
        }

        _prepare(resolvedOrders);
        _createPendingOrders(resolvedOrders);
    }

    function executeBatchWithCallback(SignedOrder[] calldata orders, bytes calldata callbackData)
        external
        payable
        override
        nonReentrant
        onlyWhitelistedCaller
    {
        uint256 ordersLength = orders.length;
        ResolvedOrder[] memory resolvedOrders = new ResolvedOrder[](ordersLength);

        unchecked {
            for (uint256 i = 0; i < ordersLength; i++) {
                resolvedOrders[i] = _resolve(orders[i]);
            }
        }

        _prepare(resolvedOrders);
        IReactorCallback(msg.sender).reactorCallback(resolvedOrders, callbackData);
        _createPendingOrders(resolvedOrders);
    }

    function settleOrder(bytes32 orderId, uint256 returnedInputAmount)
        external
        payable
        nonReentrant
    {
        PendingOrder storage p = _pendingOrders[orderId];
        if (!p.exists) revert OrderDoesNotExist();
        bool isSettleInput = returnedInputAmount > 0; 
        if (isSettleInput) {

            uint256 minInputAfterSlippage = Math.mulDiv(p.inputAmount, (MAX_SLIPPAGE_BPS - slippageBps), MAX_SLIPPAGE_BPS);
            // --- Mode 1: Executor returning input token ---
            if (returnedInputAmount < minInputAfterSlippage) {
                revert InsufficientAmount();
            }

            // Transfer ERC20 input token back to the swapper
            ERC20(p.inputToken).safeTransferFrom(msg.sender, p.swapper, returnedInputAmount);
        } else {
            // --- Mode 2: Executor fulfilling outputs ---
            uint256 outputsLength = p.outputs.length;
            for (uint256 j = 0; j < outputsLength; j++) {
                OutputToken memory output = p.outputs[j];
                output.token.transferFromFill(msg.sender, output.recipient, output.amount);
            }
        }

        // Clear order and emit event
        delete _pendingOrders[orderId];
        emit OrderSettled(orderId, isSettleInput);
    }


    /// @notice validates, injects fees, and transfers input tokens in preparation for order fill
    /// @param orders The orders to prepare
    function _prepare(ResolvedOrder[] memory orders) internal {
        uint256 ordersLength = orders.length;
        unchecked {
            for (uint256 i = 0; i < ordersLength; i++) {
                ResolvedOrder memory order = orders[i];
                _injectFees(order);
                order.validate(msg.sender);
                _transferInputTokens(order, msg.sender);
            }
        }
    }

    function _createPendingOrders(ResolvedOrder[] memory orders) internal {
        uint256 n = orders.length;
        for (uint256 i = 0; i < n; i++) {
            _createPendingOrder(orders[i]);
        }
    }

    /// @notice fills a list of orders, ensuring all outputs are satisfied
    /// @param resolvedOrder The orders to start filling
    function _createPendingOrder(ResolvedOrder memory resolvedOrder) internal {
        bytes32 orderId = resolvedOrder.hash;

        if(_pendingOrders[orderId].exists) {
            revert PendingOrderAlreadyExists();
        }

        PendingOrder storage p = _pendingOrders[orderId];
        p.executor = msg.sender;
        p.inputToken = address(resolvedOrder.input.token);
        p.inputAmount = resolvedOrder.input.amount;
        p.swapper = resolvedOrder.info.swapper;
        p.exists = true;

        uint256 outputLen = resolvedOrder.outputs.length;
        for (uint256 i = 0; i < outputLen; i++) {
            p.outputs.push(resolvedOrder.outputs[i]);
        }

        emit OrderDeferred(
            orderId,
            msg.sender,
            resolvedOrder.info.swapper,
            address(resolvedOrder.input.token),
            resolvedOrder.input.amount
        );
    }


    receive() external payable {
        // receive native asset to support native output
    }

    /// @notice Resolve order-type specific requirements into a generic order with the final inputs and outputs.
    /// @param order The encoded order to resolve
    /// @return resolvedOrder generic resolved order of inputs and outputs
    /// @dev should revert on any order-type-specific validation errors
    function _resolve(SignedOrder calldata order) internal view virtual returns (ResolvedOrder memory resolvedOrder);

    /// @notice Transfers tokens to the fillContract
    /// @param order The encoded order to transfer tokens for
    /// @param to The address to transfer tokens to
    function _transferInputTokens(ResolvedOrder memory order, address to) internal virtual;
}
