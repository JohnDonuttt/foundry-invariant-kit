// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {LibAddressSet} from "./LibAddressSet.sol";

/// @notice Boilerplate for invariant-test handlers: a pool of actors, a modifier to act as one
///         of them, per-function call counters, and time helpers.
///
///         contract MyHandler is HandlerBase {
///             constructor(Vault v) { _createActors(5); ... }
///
///             function deposit(uint256 actorSeed, uint256 amount)
///                 external useActor(actorSeed) countCall("deposit")
///             {
///                 vault.deposit(bound(amount, 1, 1e24));
///             }
///         }
abstract contract HandlerBase is Test {
    using LibAddressSet for LibAddressSet.Set;

    /// @dev every actor created by `_createActors`
    LibAddressSet.Set internal _actors;
    /// @dev the actor selected by the current `useActor` call; read it inside the handler body
    address internal currentActor;

    mapping(bytes32 => uint256) public calls;
    bytes32[] internal _callKeys;

    // ---------------------------------------------------------------------
    // actors
    // ---------------------------------------------------------------------

    /// @notice Create `n` labelled actors. Call from the handler constructor.
    function _createActors(uint256 n) internal {
        for (uint256 i; i < n; ++i) {
            address actor = makeAddr(string.concat("actor", vm.toString(i)));
            _actors.add(actor);
        }
    }

    function actorCount() public view returns (uint256) {
        return _actors.count();
    }

    function actorAt(uint256 index) public view returns (address) {
        return _actors.at(index);
    }

    /// @notice Run the function body as a pseudo-randomly chosen actor.
    modifier useActor(uint256 actorSeed) {
        currentActor = _actors.rand(actorSeed);
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // bookkeeping
    // ---------------------------------------------------------------------

    /// @notice Count how many times a handler function ran (as opposed to being skipped or reverting).
    modifier countCall(bytes32 key) {
        if (calls[key] == 0) _callKeys.push(key);
        calls[key]++;
        _;
    }

    /// @notice Print how often each handler function was called. Use in `afterInvariant()`.
    /// @dev A function that shows 0 calls means your invariants never exercised it.
    function logCallSummary() public view {
        console2.log("---- handler call summary ----");
        for (uint256 i; i < _callKeys.length; ++i) {
            console2.log(string.concat(_bytes32ToString(_callKeys[i]), ":"), calls[_callKeys[i]]);
        }
    }

    function totalCalls() public view returns (uint256 total) {
        for (uint256 i; i < _callKeys.length; ++i) {
            total += calls[_callKeys[i]];
        }
    }

    // ---------------------------------------------------------------------
    // time
    // ---------------------------------------------------------------------

    /// @notice Advance time by a bounded amount. Expose it as a handler function to let time pass.
    function _passTime(uint256 seed, uint256 minSecs, uint256 maxSecs) internal returns (uint256 secs) {
        secs = bound(seed, minSecs, maxSecs);
        skip(secs);
    }

    function _bytes32ToString(bytes32 b) private pure returns (string memory) {
        uint256 len;
        while (len < 32 && b[len] != 0) ++len;
        bytes memory out = new bytes(len);
        for (uint256 i; i < len; ++i) {
            out[i] = b[i];
        }
        return string(out);
    }
}
