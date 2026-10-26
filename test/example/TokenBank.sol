// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockToken} from "./MockToken.sol";

/// Tiny escrow used to demo the kit. Users deposit a token and can take it back.
contract TokenBank {
    MockToken public immutable token;
    uint256 public totalDeposits;
    mapping(address => uint256) public balanceOf;

    constructor(MockToken _token) {
        token = _token;
    }

    function deposit(uint256 amount) external {
        balanceOf[msg.sender] += amount;
        totalDeposits += amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        balanceOf[msg.sender] -= amount; // reverts on underflow
        totalDeposits -= amount;
        token.transfer(msg.sender, amount);
    }
}
