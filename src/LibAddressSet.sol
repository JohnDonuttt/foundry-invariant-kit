// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice A set of addresses with O(1) add/contains and index-based access.
/// @dev Handy for remembering "who has interacted so far" and picking one at random
///      from fuzzer-supplied seeds, or for summing a value across every participant.
library LibAddressSet {
    struct Set {
        address[] addrs;
        mapping(address => bool) saved;
    }

    function add(Set storage s, address a) internal {
        if (!s.saved[a]) {
            s.addrs.push(a);
            s.saved[a] = true;
        }
    }

    function contains(Set storage s, address a) internal view returns (bool) {
        return s.saved[a];
    }

    function count(Set storage s) internal view returns (uint256) {
        return s.addrs.length;
    }

    function at(Set storage s, uint256 index) internal view returns (address) {
        return s.addrs[index];
    }

    /// @notice Pick a member from an arbitrary seed. Returns address(0) if the set is empty.
    function rand(Set storage s, uint256 seed) internal view returns (address) {
        if (s.addrs.length == 0) return address(0);
        return s.addrs[seed % s.addrs.length];
    }

    function forEach(Set storage s, function(address) external func) internal {
        for (uint256 i; i < s.addrs.length; ++i) {
            func(s.addrs[i]);
        }
    }

    /// @notice Fold over the set: `acc = func(acc, member)` for each member.
    function reduce(
        Set storage s,
        uint256 acc,
        function(uint256, address) external view returns (uint256) func
    ) internal view returns (uint256) {
        for (uint256 i; i < s.addrs.length; ++i) {
            acc = func(acc, s.addrs[i]);
        }
        return acc;
    }
}
