// script/DeployUserProxyContract.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {V2DutchOrderReactor} from "../reactors/V2DutchOrderReactor.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";

contract DeployV2DutchOrderReactorContract is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Replace with your actual CoreWriter contract address
        address owner = vm.addr(deployerPrivateKey);
        IPermit2 permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        V2DutchOrderReactor dutchOrderReactor = new V2DutchOrderReactor(permit2, owner);

        vm.stopBroadcast();

        // Log the deployed contract address
        console.log("V2 Dutch Order Reactor deployed at:", address(dutchOrderReactor));
    }
}
