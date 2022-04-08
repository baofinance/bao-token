pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "../BAOv2.sol";
import "../BaoDistribution.sol";

contract BaoDistributionTest is DSTest {

    BaoToken public baoToken;
    BaoDistribution public distribution;

    function setUp() public {
        baoToken = new BaoToken(
            "Bao Finance",
            "BAO",
            15e24
        );
        distribution = new BaoDistribution(baoToken);
    }

    function testStartDistribution() public {
        distribution.startDistribution(730 days);
        distribution.claimable(address(this), 0);
    }

    function testFailStartDistributionTwice() public {
        distribution.startDistribution(1 days);
        distribution.startDistribution(1 days);
    }

    function testFailStartLongDistribution() public {
        distribution.startDistribution(1000 days);
    }
}