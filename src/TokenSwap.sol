// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract TokenSwapPool is ERC20("Liquidity Tokens", "SHARES"), ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    // Reserves
    uint public reserves0; // X
    uint public reserves1;  // Y
    uint public totalLiquidity; // K = X*Y
    // Exchange Rate
    uint public constant exchangeRate = 12; // 1.2

    // Errors
    error TokenSwap_Invalid_Address();
    error TokenSwap_Invalid_Exchange_Rate();
    error TokenSwap_TokenA_Transfer_Failed();
    error TokenSwap_TokenB_Transfer_Failed();
    error TokenSwap_Invalid_Amount();
    error TokenSwap_No_Liquidity_Shares();
    error TokenSale_No_Liquidity_Output();

    // Events
    event TokenSwap_Liquidity_Minted(address _to, uint _shareTokens);
    event TokenSwap_Liquidity_Burned(address sender, uint amount0, uint amount1, address _to);
    event TokenSwap_Swap(address, address, uint);

    constructor(address _token0, address _token1) {
        if (_token0 == address(0) || _token1 == address(0)) revert TokenSwap_Invalid_Address();
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }


    function swap(address _tokenIn) public nonReentrant returns(uint){
        // if (!(_tokenIn == address(token0) || _tokenIn == address(token1))) revert TokenSwap_Invalid_Address();
        require(!(_tokenIn == address(token0) || _tokenIn == address(token1)), "Invalid address"); 
        (uint _reserves0, uint _reserves1) = getReserves(); // bal before

        uint balance0 = IERC20(token0).balanceOf(address(this)); // bal after 
        uint balance1 = IERC20(token1).balanceOf(address(this));
        
        uint amountIn;
        uint amountToSend;
        // Amount sent 
        if (_tokenIn == address(token0)) {
            amountIn = balance0 - _reserves0;
            if (amountIn == 0) revert TokenSwap_Invalid_Amount();

            // Fixed Exchange Rate 1.2
            amountToSend = (amountIn * 10)/exchangeRate; 
            token1.safeTransfer(msg.sender, amountToSend);

            _update(balance0 - amountToSend, balance1);

        }
        else{
            amountIn = balance1 - _reserves1;
            if (amountIn == 0) revert TokenSwap_Invalid_Amount();

            // Fixed Exchange Rate 1.2
            amountToSend = (amountIn * exchangeRate)/10; 
            token0.safeTransfer(msg.sender, amountToSend);
            _update(balance0, balance1 - amountToSend);
        }

        emit TokenSwap_Swap(msg.sender, _tokenIn, amountToSend);
        return amountToSend;
    }

    function addLiquidity(address _to) public  nonReentrant returns (uint _shareTokens){
        if(_to == address(0)) revert TokenSwap_Invalid_Address();

        // balance Before Liquidator sent TokenA  and TokenB
        (uint _reserves0, uint _reserves1) = getReserves();

        // balance After Liquidator sent TokenA  and TokenB
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        // Liquidity sent 
        uint amount0In = balance0 - _reserves0;
        uint amount1In = balance1 - _reserves1;
        
        // initial liquidity 
        uint _totalSupply = totalSupply();
        if ( _totalSupply== 0){
            _shareTokens = sqrt(amount0In * amount1In); // Inspired By Uniswap V2 to Avoid Doubling Liquidity Problem
            _mint(address(0xdeadbeef), 1000); // Locking Minimum Liquidity : To Avoid Inflation Attack
        }
        else{
            _shareTokens = min((amount0In * _totalSupply) / _reserves0, (amount1In * _totalSupply) / _reserves1);
        }

        if (_shareTokens == 0) revert TokenSwap_No_Liquidity_Shares();
        _mint(_to, _shareTokens);
        _update(balance0, balance1);

        emit TokenSwap_Liquidity_Minted(_to, _shareTokens);
    }

    function removeLiquidity(address _to) public  nonReentrant{
        if(_to == address(0)) revert TokenSwap_Invalid_Address();
        
        // balance After Liquidator sent TokenA  and TokenB
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        uint _shareTokens = balanceOf(address(this));
        uint _totalSupply = totalSupply();

        uint amount0 = (_shareTokens*balance0)/_totalSupply;
        uint amount1 = (_shareTokens*balance1)/_totalSupply;

        if(amount0 == 0 || amount1 == 0) revert TokenSale_No_Liquidity_Output();
        _burn(address(this), _shareTokens);
        token0.safeTransfer(_to, amount0);
        token1.safeTransfer(_to, amount1);

        _update(balance0, balance1);

        emit TokenSwap_Liquidity_Burned(msg.sender, amount0, amount1, _to);
    }

    function getReserves() public view returns (uint, uint){
        return (reserves0, reserves1);
    }

    function _update(uint _balance0, uint _balance1) internal{
        reserves0 = _balance0;
        reserves1 = _balance1;
    }

    // From Uniswap V2
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
    
    function min(uint a, uint b) internal pure returns(uint _min){
        _min = (a < b) ? a : b;
    }
}