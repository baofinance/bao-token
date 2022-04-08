pragma solidity ^0.8.10;

import "./BAOv2.sol";
import "solmate/utils/FixedPointMathLib.sol";

contract BaoDistribution{

    // -------------------------------
    // VARIABLES
    // -------------------------------

    BaoToken public baoToken;
    mapping(address => DistInfo) public distributions;

    // -------------------------------
    // STRUCTS
    // -------------------------------

    struct DistInfo {
        uint64 dateStarted;
        uint64 lastClaim;
        uint256 amountOwedTotal;
    }

    // -------------------------------
    // EVENTS
    // -------------------------------

    event DistributionStarted(address _account, uint64 _timestamp, uint64 _duration);
    event TokensClaimed(address _account, uint64 timestamp, uint256 _amount);

    constructor(BaoToken _baoToken) {
        baoToken = _baoToken;
    }

    // -------------------------------
    // PUBLIC FUNCTIONS
    // -------------------------------

    function startDistribution(uint64 time) external {
        require(distributions[msg.sender].dateStarted == 0, "ERROR: Distribution already started");
        require(time <= 730 days); // Account may not lock for more than 2 years.

        uint delta = 730 days - time;
        uint pctDiff = FixedPointMathLib.mulDivDown(time, 1e18, 730 days) * 100;

        // This is artificial for now.
        distributions[msg.sender] = DistInfo(
            uint64(block.timestamp) - 50 days,
            uint64(block.timestamp) - 50 days,
            100e18 // TODO: User needs to provide proof of locked tokens. For the initial distribution curve testing, consider 100 tokens locked.
        );
    }

    function claimable(address _account, uint64 _timestamp) public view returns (uint256 c) {
        DistInfo memory distInfo = distributions[_account];
        require(distInfo.dateStarted != 0, "ERROR: Address unknown");
        uint64 timestamp =  _timestamp > 0 ? _timestamp : uint64(block.timestamp);

        // If the locking period has ended, the user is owed all of their tokens
        if (timestamp >= distInfo.dateStarted + 730 days) {
            // TODO - Account for previously claimed tokens, and give the user the rest.
            return c;
        }

        uint256 daysSinceStart = uint256(timestamp - distInfo.dateStarted) * 1e18 / 60 / 60 / 24;
        uint256 daysSinceClaim = uint256(timestamp - distInfo.lastClaim) * 1e18 / 60 / 60 / 24;

        // If the user has not yet claimed, give them all of the tokens that they have accrued since the
        // beginning of their distribution. If they have, give them all of the tokens that they have
        // accrued since their last claim.
        c = distInfo.dateStarted == distInfo.lastClaim
            ? distCurve(distInfo.amountOwedTotal, daysSinceStart)
            : distCurve(distInfo.amountOwedTotal, daysSinceStart) - distCurve(distInfo.amountOwedTotal, daysSinceStart - daysSinceClaim);
    }

    // -------------------------------
    // PRIVATE FUNCTIONS
    // -------------------------------

    // f(x) =
    // 0 <= x <= 100 : 0.03065x
    // 100 < x <= 730 : 0.000199914x^2 - 0.0120641x + 2.2727
    function distCurve(uint256 _amountOwedTotal, uint256 daysSinceStart) public pure returns (uint256) {
        return FixedPointMathLib.mulDivDown(
            _amountOwedTotal,
            daysSinceStart > 1e20
            // This makes my eyes bleed
            ? (FixedPointMathLib.mulDivDown(
                199914,
                FixedPointMathLib.mulDivDown(daysSinceStart, daysSinceStart, 1e18),
                1e9
            ) - FixedPointMathLib.mulDivDown(120641, daysSinceStart, 1e7) + 22727e14) / 1e2
            : FixedPointMathLib.mulDivDown(3065, daysSinceStart, 1e7),
            1e18
        );
    }
}
