// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";



contract DeployMinimal is Script {
    function deployMinimalAccount() public returns(HelperConfig, MinimalAccount) {
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helper.getConfig();

        vm.startBroadcast(config.account);
        MinimalAccount minimalAccount = new MinimalAccount(config.entryPoint);
        minimalAccount.transferOwnership(config.account);
        vm.stopBroadcast();

        return (helper, minimalAccount);
    }
}
