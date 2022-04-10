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
    bytes32[] public proof;
    uint256 public amount;

    function setUp() public {
        cheats = Cheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        // Deploy mock BAOv2 token
        baoToken = new BaoToken(
            "Bao Finance",
            "BAO"
        );

        // The distribution-merkle root we provide here is created for testing purposes only. In this distribution-merkle tree,
        // this contract's address (0xb4c79dab8f259c7aee6e5b2aa729821864227e84) is owed 1e22 (1000) tokens.
        distribution = new BaoDistribution(baoToken, 0x46c1f7da0f8cf7398e41724cc3a07901298ea14b7d4b5990062450bdb01ac5ec);

        // Mint the amount that this contract will be distributed
        amount = 1e22;
        baoToken.mint(address(distribution), amount);

        // Assign this contract's proof for usage within the tests
        proof.push(0x3cc9c7db8571b870390438e4fe0a4fcfe1a095ece4444bf77b8ca35f89e93809);
        proof.push(0x4a80075efb29ee18ecf890dbeaeafcc4c1837b96bd648d2362c6e7bce81f656c);
    }

    // -------------------------------
    // START DISTRIBUTION TESTS
    // -------------------------------

    function testStartDistribution() public {
        distribution.startDistribution(proof, amount);
    }

    function testFailStartDistributionTwice() public {
        distribution.startDistribution(proof, amount);
        distribution.startDistribution(proof, amount);
    }

    // -------------------------------
    // CLAIM TESTS
    // -------------------------------

    function testClaimable() public {
        distribution.startDistribution(proof, amount);
        uint256 claimable = distribution.claimable(address(this), 0);
        assertEq(claimable, 0);

        uint256 initialTimestamp = block.timestamp;

        // Claim every day, twice a day throughout the 2 year distribution and check if the amount
        // we've received is in-line with the distribution curve each time
        for (uint i; i < 1460; i += 1) {
            cheats.warp(block.timestamp + 12 hours);
            distribution.claim();
            assertEq(
                baoToken.balanceOf(address(this)),
                distribution.distCurve(amount, FixedPointMathLib.mulDivDown((block.timestamp - initialTimestamp), 1e18, 86400))
            );
        }

        // Ensure the total amount this contract is owed has been claimed after the full distribution.
        (,,uint256 owed) = distribution.distributions(address(this));
        assertEq(baoToken.balanceOf(address(this)), amount);
    }

    function testClaimOnce() public {
        distribution.startDistribution(proof, amount);

        cheats.warp(block.timestamp + 731 days);
        distribution.claim();

        assertEq(baoToken.balanceOf(address(this)), amount);
    }

    function testFailClaimZeroTokens() public {
        distribution.startDistribution(proof, amount);
        distribution.claim();
    }

    function testFailClaimableUnrecognizedAddress() public {
        distribution.claimable(address(0), 0);
    }
}