pragma solidity ^0.8.10;

import "./BAOv2.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "solmate/utils/ReentrancyGuard.sol";

contract BaoDistribution is ReentrancyGuard {

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

    function startDistribution() external {
        require(distributions[msg.sender].dateStarted == 0, "ERROR: Distribution already started");

        // uint delta = 730 days - time;
        // uint pctDiff = FixedPointMathLib.mulDivDown(time, 1e18, 730 days) * 100;

        // This is artificial for now.
        uint64 now = uint64(block.timestamp);
        distributions[msg.sender] = DistInfo(
            now,
            now,
            1e22 // TODO: User needs to provide proof of locked tokens. For the initial distribution curve testing, consider 100 tokens locked.
        );
    }

    function claim() external nonReentrant {
        uint256 claimable = claimable(msg.sender, 0);
        require(claimable > 0, "ERROR: Nothing to claim");
        uint64 timestamp = uint64(block.timestamp);

        // Update account's DistInfo
        distributions[msg.sender].lastClaim = timestamp;

        baoToken.transfer(msg.sender, claimable);

        // Emit tokens claimed event for logging
        emit TokensClaimed(msg.sender, timestamp, claimable);
    }

    function claimable(address _account, uint64 _timestamp) public view returns (uint256 c) {
        DistInfo memory distInfo = distributions[_account];
        require(distInfo.dateStarted != 0, "ERROR: Address unknown");
        uint64 timestamp = _timestamp == 0 ? uint64(block.timestamp) : _timestamp;

        uint256 daysSinceStart = FixedPointMathLib.mulDivDown(uint256(timestamp - distInfo.dateStarted), 1e18, 86400);
        uint256 daysSinceClaim = FixedPointMathLib.mulDivDown(uint256(timestamp - distInfo.lastClaim), 1e18, 86400);

        // Allow the account to claim all tokens accrued since the last time they've claimed.
        c = distCurve(distInfo.amountOwedTotal, daysSinceStart) - distCurve(distInfo.amountOwedTotal, daysSinceStart - daysSinceClaim);
    }

    // -------------------------------
    // PRIVATE FUNCTIONS
    // -------------------------------

    // f(x) =
    // 0 <= x <= 100 : 0.03065x
    // 100 < x <= 730 : 0.000199914x^2 - 0.0120641x + 2.2727
    function distCurve(uint256 _amountOwedTotal, uint256 daysSinceStart) public pure returns (uint256) {
        return daysSinceStart >= 730e18 ? _amountOwedTotal : FixedPointMathLib.mulDivDown(
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
