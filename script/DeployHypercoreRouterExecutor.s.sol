// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {HypercoreRouterExecutor} from "../src/sample-executors/HypercoreRouterExecutor.sol";
import {ISwapRouter02} from "../src/external/ISwapRouter02.sol";
import {ITrustedReactor} from "../src/interfaces/ITrustedReactor.sol";
import {TrustedExclusiveDutchOrderReactor} from "../src/reactors/TrustedExclusiveDutchOrderReactor.sol";

contract DeployHypercoreRouterExecutor is Script {
    function setUp() public {}

    function run() public returns (HypercoreRouterExecutor executor) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        ITrustedReactor reactor = ITrustedReactor(vm.envAddress("FOUNDRY_TRUSTED_HYPER_CORE_DEPLOY_REACTOR"));
        // can encode with cast abi-encode "foo(address[])" "[addr1, addr2, ...]"
        bytes memory encodedAddresses = vm.envBytes("FOUNDRY_TRUSTED_HYPER_CORE_FILLER_WHITELIST_ENCODED");
        address owner = vm.envAddress("FOUNDRY_SWAPROUTER02EXECUTOR_DEPLOY_OWNER");

        address[] memory decodedAddresses = abi.decode(encodedAddresses, (address[]));

        vm.startBroadcast(privateKey);
        executor = new HypercoreRouterExecutor{salt: 0x00}(decodedAddresses, reactor, owner);

        TrustedExclusiveDutchOrderReactor(payable(vm.envAddress("FOUNDRY_TRUSTED_HYPER_CORE_DEPLOY_REACTOR"))).setWhitelist(address(executor), true);

        vm.stopBroadcast();


        console2.log("HypercoreRouterExecutor", address(executor));
        console2.log("owner", executor.owner());
    }
}
