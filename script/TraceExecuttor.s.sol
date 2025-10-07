// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

contract TraceExecutor is Script {
    address constant EXECUTOR = 0x87ac8F4aD3BaB7c213d106BDa1Fc2B1759379868;

    function run(bytes memory callData) external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address from = vm.addr(pk);

        console2.log("Executor:", EXECUTOR);
        console2.log("From:", from);

        vm.startBroadcast(pk);
        (bool success, bytes memory result) = EXECUTOR.call(callData);
        vm.stopBroadcast();

        if (!success) {
            console2.log("Reverted");
            if (result.length > 0) console2.logBytes(result);
            else console2.log("No revert reason returned");
        } else {
            console2.log("Success");
        }
    }
}
