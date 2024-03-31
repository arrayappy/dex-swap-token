// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TokenA is ERC20 ("A Token", "AA"){
    constructor() {
        _mint(msg.sender, 100000 ether);
    }
}

contract TokenB is ERC20 ("B Token", "BB"){
    constructor() {
        _mint(msg.sender, 100000 ether);
    }
}