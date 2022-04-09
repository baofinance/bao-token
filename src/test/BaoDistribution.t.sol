pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "../BAOv2.sol";
import "../BaoDistribution.sol";
import "solmate/utils/FixedPointMathLib.sol";

interface Cheats {
    function warp(uint256) external;
}

contract BaoDistributionTest is DSTest {

    Cheats public cheats;
    BaoToken public baoToken;
    BaoDistribution public distribution;

    function setUp() public {
        cheats = Cheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        baoToken = new BaoToken(
            "Bao Finance",
            "BAO",
            15e24
        );
        distribution = new BaoDistribution(baoToken);
        baoToken.mint(address(distribution), 1e22);
    }

    // -------------------------------
    // START DISTRIBUTION TESTS
    // -------------------------------

    function testStartDistribution() public {
        distribution.startDistribution();
    }

    function testFailStartDistributionTwice() public {
        distribution.startDistribution();
        distribution.startDistribution();
    }

    // -------------------------------
    // CLAIM TESTS
    // -------------------------------

    function testClaimable() public {
        distribution.startDistribution();
        uint256 claimable = distribution.claimable(address(this), 0);
        assertEq(claimable, 0);

        uint256 initialTimestamp = block.timestamp;

        // Claim every day, twice a day throughout the 2 year cycle and check if the amount
        // we've received is in-line with the distribution curve each time
        for (uint i; i < 1460; i += 1) {
            cheats.warp(block.timestamp + 12 hours);
            distribution.claim();
            assertEq(
                baoToken.balanceOf(address(this)),
                distribution.distCurve(1e22, FixedPointMathLib.mulDivDown((block.timestamp - initialTimestamp), 1e18, 86400))
            );
        }
    }

    function testClaimOnce() public {
        distribution.startDistribution();

        cheats.warp(block.timestamp + 731 days);
        distribution.claim();

        assertEq(baoToken.balanceOf(address(this)), 1e22);
    }

    function testFailClaimZeroTokens() public {
        distribution.startDistribution();
        distribution.claim();
    }

    function testFailClaimableUnrecognizedAddress() public {
        distribution.claimable(address(0), 0);
    }
}