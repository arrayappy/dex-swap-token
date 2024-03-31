// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {TokenSwapPool} from "../src/TokenSwap.sol";
import {TokenA, TokenB} from "../src/MyTwoTokens.sol";
import {TokenSwapScript} from "../script/Deploy.s.sol";


import {SafeERC20} from "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";


contract TokenSwapTest is Test {
    using SafeERC20 for TokenA;
    using SafeERC20 for TokenB;
    TokenA public tokenA;
    TokenB public tokenB;
    TokenSwapPool public tokenSwap;
    address public user;
    function setUp() public {
        tokenA = new TokenA();
        tokenB = new TokenB();
        tokenSwap = new TokenSwapPool(address(tokenA), address(tokenB));

        user = address(0x1);
        tokenA.safeTransfer(user, 1000);
        tokenB.safeTransfer(user, 1000);
    }

    function testConstructor() public{
        vm.expectRevert(TokenSwapPool.TokenSwap_Invalid_Address.selector);
        tokenSwap = new TokenSwapPool(address(0), address(0));
    }

    function testAddLiquidityFailing() public {
        vm.startPrank(user);
        vm.expectRevert(TokenSwapPool.TokenSwap_Invalid_Address.selector);
        tokenSwap.addLiquidity(address(0));

        vm.expectRevert(TokenSwapPool.TokenSwap_No_Liquidity_Shares.selector);
        tokenSwap.addLiquidity(user);


        tokenA.transfer(address(tokenSwap), 120);
        tokenB.transfer(address(tokenSwap), 0);
        vm.expectRevert(TokenSwapPool.TokenSwap_No_Liquidity_Shares.selector);
        tokenSwap.addLiquidity(user);

    }

    function testAddLiquidity() public {
        vm.startPrank(user);

        assertEq(tokenSwap.totalSupply(), 0);
        assertEq(tokenSwap.reserves0(), 0);
        assertEq(tokenSwap.reserves1(), 0);
        tokenA.transfer(address(tokenSwap), 120);
        tokenB.transfer(address(tokenSwap), 100);
        
        uint expectedShares = sqrt(120*100);
        vm.expectEmit(true,true,false, false);
        emit TokenSwapPool.TokenSwap_Liquidity_Minted(user, expectedShares);
        tokenSwap.addLiquidity(user);
        assertEq(tokenSwap.balanceOf(address(0xdeadbeef)), 1000);
        uint mintedShares = tokenSwap.balanceOf(user);
        assertEq(expectedShares, mintedShares);
        assertEq(tokenSwap.totalSupply(), 1000+mintedShares);

    }

    function testAmountAddLiquidityMultipleTimes() public {
        
        testAddLiquidity();

        vm.startPrank(user);
        assertEq(tokenSwap.totalSupply(), 1109);
        assertEq(tokenSwap.reserves0(), 120);
        assertEq(tokenSwap.reserves1(), 100);
        tokenA.transfer(address(tokenSwap), 120);
        tokenB.transfer(address(tokenSwap), 100);
        tokenSwap.addLiquidity(user);
 
        uint expectedShares = min((120*1109)/120, (100*1109)/100);
        uint mintedShares = tokenSwap.balanceOf(user) - 109; // Minus Previous Shares
        assertEq(expectedShares, mintedShares);
        assertEq(tokenSwap.totalSupply(), 1109+mintedShares);

    }

    function testAmountAddLiquidityDifferentRatio() public {
        
        testAddLiquidity();

        vm.startPrank(user);
        assertEq(tokenSwap.totalSupply(), 1109);
        assertEq(tokenSwap.reserves0(), 120);
        assertEq(tokenSwap.reserves1(), 100);
        tokenA.transfer(address(tokenSwap), 80);
        tokenB.transfer(address(tokenSwap), 100);
        tokenSwap.addLiquidity(user);
 
        uint expectedShares = min(uint(80*1109)/120, (100*1109)/100);
        uint mintedShares = tokenSwap.balanceOf(user) - 109; // Minus Previous Shares
        assertEq(expectedShares, mintedShares);
        assertEq(tokenSwap.totalSupply(), 1109+mintedShares);

    }

    function testRemoveLiquidityFail() public{
        testAddLiquidity();
        vm.startPrank(user);
        vm.expectRevert(TokenSwapPool.TokenSwap_Invalid_Address.selector);
        tokenSwap.removeLiquidity(address(0));

        vm.expectRevert(TokenSwapPool.TokenSale_No_Liquidity_Output.selector);
        tokenSwap.removeLiquidity(address(0xff));
    }
    function testRemoveLiquidity() public{
        testAddLiquidity();
        vm.startPrank(user);
        uint mintedShares = tokenSwap.balanceOf(user); // 109
        uint amount0 = (mintedShares*120)/1109;
        uint amount1 = (mintedShares*100)/1109;

        tokenSwap.transfer(address(tokenSwap), mintedShares);
        vm.expectEmit(true,true,false, false);
        emit TokenSwapPool.TokenSwap_Liquidity_Burned(user, amount0, amount1, user);
        tokenSwap.removeLiquidity(address(0xff));

        uint tokensA = tokenA.balanceOf(address(0xff));
        uint tokensB = tokenB.balanceOf(address(0xff));
        
        assertEq(tokensA, amount0);
        assertEq(tokensB, amount1);
        assertEq(tokenSwap.totalSupply(), 1109-mintedShares);

    }

    function testSwapMyA() public{
        testAddLiquidity();
        uint userToken0Bal = tokenA.balanceOf(user);
        uint userToken1Bal = tokenB.balanceOf(user);
        assertEq(userToken0Bal, 880); // 1000-120
        assertEq(userToken1Bal, 900); // 1000-100

        tokenA.transfer(address(tokenSwap), 24);
        uint amount1Received = tokenSwap.swap(address(tokenA));

        assertEq(amount1Received, 20); // 1.2 exchange rate
        assertEq(tokenA.balanceOf(user), 880-24);
        assertEq(tokenB.balanceOf(user), 900+20);        
    }

    function testSwapMyB() public{
        testAddLiquidity();
        uint userToken0Bal = tokenA.balanceOf(user);
        uint userToken1Bal = tokenB.balanceOf(user);
        assertEq(userToken0Bal, 880); // 1000-120
        assertEq(userToken1Bal, 900); // 1000-100

        tokenB.transfer(address(tokenSwap), 20);
        uint amount0Received = tokenSwap.swap(address(tokenB));

        assertEq(amount0Received, 24); // 1.2 exchange rate
        assertEq(tokenA.balanceOf(user), 880+24);
        assertEq(tokenB.balanceOf(user), 900-20);        
    }

    function testSwapFails() public{
        testAddLiquidity();
        vm.expectRevert(TokenSwapPool.TokenSwap_Invalid_Amount.selector);
        tokenSwap.swap(address(tokenA));
        vm.expectRevert(TokenSwapPool.TokenSwap_Invalid_Amount.selector);
        tokenSwap.swap(address(tokenB));

        vm.expectRevert(TokenSwapPool.TokenSwap_Invalid_Address.selector);
        tokenSwap.swap(address(0xffff));

    }
    function testGetReserves() public{
        testAddLiquidity();
        (uint r0, uint r1) = tokenSwap.getReserves();
        assertEq(r0, 120);
        assertEq(r1, 100);
    }

    function testDeployScript() public {
        TokenSwapScript script = new TokenSwapScript();
        script.run();
        assertTrue(address(script.tokenA())!=address(0));
        assertTrue(address(script.tokenB())!=address(0));
        assertTrue(address(script.tokenSwap())!=address(0));
    }


    // for Testing Utils
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
    function min(uint a, uint b) public pure returns(uint _min){
        _min = (a < b) ? a : b;
    }
}
