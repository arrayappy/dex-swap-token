// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {TokenSwapPool} from "../src/TokenSwap.sol";
import {TokenA, TokenB} from "../src/MyTwoTokens.sol";

contract TokenSwapScript is Script {
    TokenA public tokenA;
    TokenB public tokenB;
    TokenSwapPool public tokenSwap;
    
    function run() public {
        vm.broadcast();
        tokenA = new TokenA();
        tokenB = new TokenB();
        tokenSwap = new TokenSwapPool(address(tokenA), address(tokenB));
    }
}
