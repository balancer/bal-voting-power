// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script, console2} from "forge-std/Script.sol";
import {BalVotingPower} from "../src/BalVotingPower.sol";

contract Deploy is Script {
    function run() external returns (address deployed) {
        vm.startBroadcast();
        deployed = address(new BalVotingPower());
        vm.stopBroadcast();

        console2.log("BalVotingPower deployed at", deployed);
    }
}
