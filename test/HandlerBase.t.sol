// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HandlerBase} from "invariant-kit/HandlerBase.sol";
import {LibAddressSet} from "invariant-kit/LibAddressSet.sol";

/// Records who called it, so tests can see which address the handler acted as.
contract Recorder {
    address public lastCaller;

    function ping() external {
        lastCaller = msg.sender;
    }
}

contract ProbeHandler is HandlerBase {
    Recorder public recorder;
    uint256 public lastTimestamp;

    constructor(uint256 n, Recorder _recorder) {
        _createActors(n);
        recorder = _recorder;
    }

    function act(uint256 seed) external useActor(seed) countCall("act") {
        recorder.ping();
    }

    function other() external countCall("other") {}

    function wait(uint256 seed) external returns (uint256 secs) {
        secs = _passTime(seed, 10, 20);
        lastTimestamp = block.timestamp;
    }
}

contract HandlerBaseTest is Test {
    ProbeHandler handler;
    Recorder recorder;

    function setUp() public {
        recorder = new Recorder();
        handler = new ProbeHandler(4, recorder);
    }

    function test_createsRequestedNumberOfDistinctActors() public view {
        assertEq(handler.actorCount(), 4);
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                assertTrue(handler.actorAt(i) != handler.actorAt(j));
            }
        }
    }

    function test_useActor_callsAsTheSelectedActor() public {
        handler.act(2);
        assertEq(recorder.lastCaller(), handler.actorAt(2));
        // the seed wraps around
        handler.act(4 + 1);
        assertEq(recorder.lastCaller(), handler.actorAt(1));
    }

    function test_useActor_stopsPranking() public {
        handler.act(0);
        // the prank must not leak: a direct call afterwards comes from this contract
        recorder.ping();
        assertEq(recorder.lastCaller(), address(this));
    }

    function test_countCall_tracksEachKey() public {
        handler.act(0);
        handler.act(1);
        handler.other();

        assertEq(handler.calls("act"), 2);
        assertEq(handler.calls("other"), 1);
        assertEq(handler.totalCalls(), 3);
    }

    function testFuzz_passTime_staysInBounds(uint256 seed) public {
        uint256 before = block.timestamp;
        uint256 secs = handler.wait(seed);

        assertGe(secs, 10);
        assertLe(secs, 20);
        assertEq(block.timestamp, before + secs);
    }
}

contract SetHarness {
    using LibAddressSet for LibAddressSet.Set;

    LibAddressSet.Set internal s;
    mapping(address => uint256) public weight;

    function add(address a, uint256 w) external {
        s.add(a);
        weight[a] = w;
    }

    function count() external view returns (uint256) {
        return s.count();
    }

    function contains(address a) external view returns (bool) {
        return s.contains(a);
    }

    function rand(uint256 seed) external view returns (address) {
        return s.rand(seed);
    }

    function _plus(uint256 acc, address a) external view returns (uint256) {
        return acc + weight[a];
    }

    function total() external view returns (uint256) {
        return s.reduce(0, this._plus);
    }
}

contract LibAddressSetTest is Test {
    SetHarness h;
    address a = address(0xA);
    address b = address(0xB);

    function setUp() public {
        h = new SetHarness();
    }

    function test_addIsIdempotent() public {
        h.add(a, 1);
        h.add(a, 1);
        assertEq(h.count(), 1);
        assertTrue(h.contains(a));
        assertFalse(h.contains(b));
    }

    function test_randOnEmptyReturnsZero() public view {
        assertEq(h.rand(123), address(0));
    }

    function testFuzz_randAlwaysReturnsAMember(uint256 seed) public {
        h.add(a, 1);
        h.add(b, 2);
        address picked = h.rand(seed);
        assertTrue(picked == a || picked == b);
    }

    function test_reduceSumsAcrossMembers() public {
        h.add(a, 5);
        h.add(b, 7);
        assertEq(h.total(), 12);
    }
}
