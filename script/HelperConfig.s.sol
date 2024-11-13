// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfig is Script {
    error HelperConfig__invalidChainId();

    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant public ANVIL_CHAIN_ID = 31337;
    address constant BURNER_WALLET = 0xa5A0d28D045359Aa6f68AD40C71C414d2f304734;
    // address constant FOUNDRY_DEFAULT_WALLET =
    //     0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    address constant public ANVIL_DEFAULT_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    NetworkConfig public activeConfig;

    function getChainId() public view returns (uint256) {
        return block.chainid;
    }

    function getConfig() public returns (NetworkConfig memory) {
        uint256 chainId = getChainId();
        if (chainId == ETH_SEPOLIA_CHAIN_ID)
            activeConfig = getEthSepoliaConfig();
        else if (chainId == ZKSYNC_SEPOLIA_CHAIN_ID)
            activeConfig = getZksyncSepoliaConfig();
        else if (chainId == ANVIL_CHAIN_ID)
            activeConfig = getOrCreateAnvilConfig();
        else revert HelperConfig__invalidChainId();
        return activeConfig;
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
                account: BURNER_WALLET
            });
    }

    function getZksyncSepoliaConfig()
        public
        pure
        returns (NetworkConfig memory)
    {
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET});
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeConfig.account != address(0)) return activeConfig;

        console2.log("depoloying Mock EntryPoint...");
        vm.startBroadcast(ANVIL_DEFAULT_ADDRESS);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();
        
        return
            NetworkConfig({
                entryPoint: address(entryPoint),
                account: ANVIL_DEFAULT_ADDRESS
            });
    }
}
