// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {FeeControllerInputFees} from "../src/fee-controllers/FeeControllerInputFees.sol";

contract DeployFeeControllerInputFees is Script {

    function setUp() public {}

    function run() public returns (address) {
        address owner = vm.envAddress("FOUNDRY_SWAPROUTER02EXECUTOR_DEPLOY_OWNER");
        address feeReceiver = vm.envAddress("FOUNDRY_FEE_RECEIVER");        
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

        FeeControllerInputFees feeController = new FeeControllerInputFees{salt: 0x00}(owner, feeReceiver);
        console2.log("Fee controller", address(feeController));

        vm.stopBroadcast();

        return address(feeController);
    }
}
