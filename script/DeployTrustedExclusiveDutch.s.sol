// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {TrustedExclusiveDutchOrderReactor} from "../src/reactors/TrustedExclusiveDutchOrderReactor.sol";
import {OrderQuoter} from "../src/lens/OrderQuoter.sol";

struct ExclusiveDutchDeployment {
    IPermit2 permit2;
    TrustedExclusiveDutchOrderReactor reactor;
    OrderQuoter quoter;
    address owner;
}

contract DeployTrustedExclusiveDutch is Script {
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address owner = vm.envAddress("FOUNDRY_SWAPROUTER02EXECUTOR_DEPLOY_OWNER");


    function setUp() public {}

    function run() public returns (ExclusiveDutchDeployment memory deployment) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        TrustedExclusiveDutchOrderReactor reactor = new TrustedExclusiveDutchOrderReactor(IPermit2(PERMIT2), owner);
        console2.log("Reactor", address(reactor));

        OrderQuoter quoter = new OrderQuoter();
        console2.log("Quoter", address(quoter));
        console2.log("OWNER", reactor.owner());

        vm.stopBroadcast();

        return ExclusiveDutchDeployment(IPermit2(PERMIT2), reactor, quoter, reactor.owner());
    }
}
