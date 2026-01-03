// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {SimpleMockToken} from "../src/Token.sol";
import {TokenMintingTrap} from "../src/TokenMintingTrap.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // SimpleMockToken token = new SimpleMockToken("HoodiTrapToken", "HTT");
        // console2.log("MockToken deployed at:", address(token));
        // Token already deployed at 0x42f5236Efd494B97f9e64eE82062462754bFf9b4
        
        TokenMintingTrap trap = new TokenMintingTrap();
        console2.log("TokenMintingTrap deployed at:", address(trap));

        vm.stopBroadcast();

    }
}
