// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../BAOv2.sol";

contract ContractTest is DSTest {
    BaoToken public baoToken;

    function setUp() public {
        baoToken = new BaoToken(
            "Bao Finance",
            "BAO"
        );
    }
}
