// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockToken} from "./MockToken.sol";
import {HandlerBase} from "invariant-kit/HandlerBase.sol";
import {LibAddressSet} from "invariant-kit/LibAddressSet.sol";
import {TokenBank} from "./TokenBank.sol";

contract BankHandler is HandlerBase {
    using LibAddressSet for LibAddressSet.Set;

    TokenBank public bank;
    MockToken public token;

    // everyone who has deposited at least once
    LibAddressSet.Set internal depositors;
    uint256 public ghostDeposited;
    uint256 public ghostWithdrawn;

    constructor(TokenBank _bank, MockToken _token) {
        bank = _bank;
        token = _token;
        _createActors(5);

        for (uint256 i; i < actorCount(); ++i) {
            token.mint(actorAt(i), 1_000_000e18);
            vm.prank(actorAt(i));
            token.approve(address(bank), type(uint256).max);
        }
    }

    function deposit(uint256 actorSeed, uint256 amount) external useActor(actorSeed) countCall("deposit") {
        amount = bound(amount, 0, token.balanceOf(currentActor));
        bank.deposit(amount);

        depositors.add(currentActor);
        ghostDeposited += amount;
    }

    function withdraw(uint256 actorSeed, uint256 amount) external useActor(actorSeed) countCall("withdraw") {
        amount = bound(amount, 0, bank.balanceOf(currentActor));
        bank.withdraw(amount);
        ghostWithdrawn += amount;
    }

    function passTime(uint256 secs) external countCall("passTime") {
        _passTime(secs, 1, 1 days);
    }

    // used with LibAddressSet.reduce
    function _addBalance(uint256 acc, address who) external view returns (uint256) {
        return acc + bank.balanceOf(who);
    }

    function sumOfBalances() external view returns (uint256) {
        return depositors.reduce(0, this._addBalance);
    }
}

contract TokenBankInvariantTest is Test {
    TokenBank bank;
    MockToken token;
    BankHandler handler;

    function setUp() public {
        token = new MockToken();
        bank = new TokenBank(token);
        handler = new BankHandler(bank, token);

        targetContract(address(handler));
    }

    function invariant_totalMatchesSumOfBalances() public view {
        assertEq(bank.totalDeposits(), handler.sumOfBalances());
    }

    function invariant_bankHoldsWhatItOwes() public view {
        assertEq(token.balanceOf(address(bank)), bank.totalDeposits());
    }

    function invariant_flowsAddUp() public view {
        assertEq(handler.ghostDeposited() - handler.ghostWithdrawn(), bank.totalDeposits());
    }

    function afterInvariant() public view {
        handler.logCallSummary();
    }
}
