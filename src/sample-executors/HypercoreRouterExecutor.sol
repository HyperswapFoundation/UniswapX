// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Owned} from "solmate/src/auth/Owned.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";
import {IReactorCallback} from "../interfaces/IReactorCallback.sol";
import {ITrustedReactor} from "../interfaces/ITrustedReactor.sol";
import {CurrencyLibrary} from "../lib/CurrencyLibrary.sol";
import {ResolvedOrder, SignedOrder} from "../base/ReactorStructs.sol";

/// @notice A fill contract that uses SwapRouter02 to execute trades
contract HypercoreRouterExecutor is IReactorCallback, Owned {
    using SafeTransferLib for ERC20;
    using CurrencyLibrary for address;

    event ReactorChanged(address newReactor, address oldReactor);

    /// @notice thrown if reactorCallback is called with a non-whitelisted filler
    error CallerNotWhitelisted();
    /// @notice thrown if reactorCallback is called by an address other than the reactor
    error MsgSenderNotReactor();
    error InsufficientAmount();


    mapping(address => bool) whitelistedCallers;
    ITrustedReactor public reactor;

    modifier onlyWhitelistedCaller() {
        if (whitelistedCallers[msg.sender] == false) {
            revert CallerNotWhitelisted();
        }
        _;
    }

    modifier onlyReactor() {
        if (msg.sender != address(reactor)) {
            revert MsgSenderNotReactor();
        }
        _;
    }

    function updateWhitelist(address wl, bool isAllowed) external onlyOwner {
        whitelistedCallers[wl] = isAllowed;
    }

    constructor(address[] memory _whitelistedCallers, ITrustedReactor _reactor, address _owner)
        Owned(_owner)
    {
        for (uint256 i = 0; i < _whitelistedCallers.length; i++) {
            whitelistedCallers[_whitelistedCallers[i]] = true;
        }
        reactor = _reactor;
    }

    /// @notice assume that we already have all output tokens
    function execute(SignedOrder calldata order, bytes calldata callbackData) external onlyWhitelistedCaller {
        reactor.executeWithCallback(order, callbackData);
    }

    /// @notice assume that we already have all output tokens
    function executeBatch(SignedOrder[] calldata orders, bytes calldata callbackData) external onlyWhitelistedCaller {
        reactor.executeBatchWithCallback(orders, callbackData);
    }

    /// @notice fill UniswapX orders using SwapRouter02
    /// @param callbackData It has the below encoded:
    /// address[] memory tokensToApproveForSwapRouter02: Max approve these tokens to swapRouter02
    /// address[] memory tokensToApproveForReactor: Max approve these tokens to reactor
    /// bytes[] memory multicallData: Pass into swapRouter02.multicall()
    function reactorCallback(ResolvedOrder[] calldata orders, bytes calldata callbackData) external onlyReactor {
        (
            address[] memory apiWallets,
            address[] memory tokensToApproveForReactor
        ) = abi.decode(callbackData, (address[], address[]));

        uint256 tokensToApproveForReactorLength = tokensToApproveForReactor.length;
        unchecked {
            for (uint256 i = 0; i < tokensToApproveForReactorLength; i++) {
                ERC20(tokensToApproveForReactor[i]).safeApprove(address(reactor), type(uint256).max);
            }
        }

        uint256 orderLength = orders.length;
        unchecked { 
            for (uint256 i = 0; i < orderLength; i++) {
                address apiWallet = apiWallets[i];
                ResolvedOrder memory order = orders[i];
                order.input.token.transfer(apiWallet, order.input.amount);
            }
        }
    }

    /// @notice Transfer all ETH in this contract to the recipient. Can only be called by owner.
    /// @param recipient The recipient of the ETH
    function withdrawETH(address recipient) external onlyOwner {
        SafeTransferLib.safeTransferETH(recipient, address(this).balance);
    }

    /// @notice Transfer the entire balance of an ERC20 token in this contract to a recipient. Can only be called by owner.
    /// @param token The ERC20 token to withdraw
    /// @param to The recipient of the tokens
    function withdrawERC20(ERC20 token, address to) external onlyOwner {
        token.safeTransfer(to, token.balanceOf(address(this)));
    }

    /// @notice Update the reactor contract address. Can only be called by owner.
    /// @param _reactor The new reactor contract address
    function updateReactor(ITrustedReactor _reactor) external onlyOwner {
        emit ReactorChanged(address(_reactor), address(reactor));
        reactor = _reactor;
    }

    /// @notice Necessary for this contract to receive ETH when calling unwrapWETH()
    receive() external payable {}
}
