// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {EigenUser} from "src/EigenUser.sol";
import {EigenStaking} from "src/EigenStaking.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        address eigenUserImplementation = address(new EigenUser());

        new EigenStaking({
            owner_: vm.envAddress("OWNER"),
            operator_: vm.envAddress("OPERATOR"),
            eigenPodManager_: _eigenPodManager(),
            treasury_: vm.envAddress("TREASURY"),
            oneTimeFee_: 0,
            executionFee_: 2500, // 25%
            restakingFee_: 2500, // 25%
            refundDelay_: 0,
            implementation_: eigenUserImplementation
        });

        vm.stopBroadcast();
    }

    function _eigenPodManager() internal view returns (address) {
        if (block.chainid == 1) return 0x91E677b07F7AF907ec9a428aafA9fc14a0d3A338;
        else if (block.chainid == 17000) return 0x30770d7E3e71112d7A6b7259542D1f680a70e315;
        else revert("Unsupported chain.");
    }
}

contract Upgrade is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        address eigenUserImplementation = address(new EigenUser());

        EigenStaking(payable(vm.envAddress("STAKING_ADDRESS"))).setImplementation(eigenUserImplementation);
    }
}
