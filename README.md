# foundry-invariant-kit

Small helpers that remove the boilerplate from Foundry invariant tests: a pool of actors, a modifier to act as one of them, call counters, and an address set you can sample from and sum over.

Invariant tests are worth writing, but every project ends up re-implementing the same handler plumbing. This is that plumbing, in two files.

## Install

```sh
forge install JohnDonuttt/foundry-invariant-kit
```

Add the remapping to `remappings.txt`:

```
invariant-kit/=lib/foundry-invariant-kit/src/
```

Requires [forge-std](https://github.com/foundry-rs/forge-std).

## Usage

```solidity
import {HandlerBase} from "invariant-kit/HandlerBase.sol";
import {LibAddressSet} from "invariant-kit/LibAddressSet.sol";

contract BankHandler is HandlerBase {
    using LibAddressSet for LibAddressSet.Set;

    LibAddressSet.Set internal depositors;

    constructor(Bank _bank, Token _token) {
        bank = _bank;
        _createActors(5);                       // 5 labelled addresses
        // ...fund and approve them here
    }

    function deposit(uint256 actorSeed, uint256 amount)
        external
        useActor(actorSeed)      // runs the body as one of the actors
        countCall("deposit")     // tracks how often this actually ran
    {
        amount = bound(amount, 0, token.balanceOf(currentActor));
        bank.deposit(amount);
        depositors.add(currentActor);
    }

    function passTime(uint256 secs) external countCall("passTime") {
        _passTime(secs, 1, 1 days);
    }
}
```

Then in the invariant test:

```solidity
function setUp() public {
    // ...
    targetContract(address(handler));
}

function afterInvariant() public view {
    handler.logCallSummary();   // shows how many times each handler function ran
}
```

A full working example is in [`test/example`](test/example): a token bank with three invariants (internal total matches the sum of balances, the contract holds what it owes, deposits minus withdrawals equals the total).

## API

### `HandlerBase`

| Member | What it does |
| --- | --- |
| `_createActors(n)` | Creates `n` labelled addresses (`actor0`, `actor1`, ...). Call it in the handler constructor |
| `useActor(seed)` | Modifier. Picks `actors[seed % n]`, pranks as it, and sets `currentActor` |
| `countCall(key)` | Modifier. Increments `calls[key]` |
| `logCallSummary()` | Logs the per-function counts. A function showing 0 means your invariants never exercised it |
| `totalCalls()` | Sum of all counted calls |
| `actorCount()` / `actorAt(i)` | Read the actor pool |
| `_passTime(seed, min, max)` | Skips a bounded number of seconds |

### `LibAddressSet`

`add`, `contains`, `count`, `at`, `rand(seed)` (returns `address(0)` if empty), `forEach`, and `reduce` for folding a value across members. `forEach` and `reduce` take external function references, so the callback must be an `external` function on the handler (pass it as `this.fn`).

## Notes

- `fail_on_revert = false` is the setting I use with these handlers, and `bound()` should do most of the input shaping. If you see a lot of reverts in the call table, tighten the bounds.
- The pranked address applies to calls the handler makes onward (to your target contract), not to the handler's own `msg.sender`.
- Tests: `forge test`. They cover the actor pool, modifiers, counters, time bounds, and the address set, including fuzz tests. The example invariants were also checked against a deliberately broken bank to confirm they fail when something is wrong.

## License

MIT
