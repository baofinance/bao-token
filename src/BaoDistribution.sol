pragma solidity ^0.8.10;

import "./BAOv2.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "solmate/utils/ReentrancyGuard.sol";
import "@openzeppelin/utils/cryptography/MerkleProof.sol";

contract BaoDistribution is ReentrancyGuard {

    // -------------------------------
    // VARIABLES
    // -------------------------------

    BaoToken public baoToken;
    mapping(address => DistInfo) public distributions;
    address public treasury;

    // -------------------------------
    // CONSTANTS
    // -------------------------------

    bytes32 public immutable merkleRoot;

    // -------------------------------
    // STRUCTS
    // -------------------------------

    struct DistInfo {
        uint64 dateStarted;
        uint64 dateEnded;
        uint64 lastClaim;
        uint256 amountOwedTotal;
    }

    // -------------------------------
    // EVENTS
    // -------------------------------

    event DistributionStarted(address _account);
    event TokensClaimed(address _account, uint256 _amount);
    event DistributionEnded(address _account, uint256 _amount);

    /**
     * Create a new BaoDistribution contract.
     *
     * @param _baoToken Token to distribute.
     * @param _merkleRoot Merkle root to verify accounts' inclusion and amount owed when starting their distribution.
     */
    constructor(BaoToken _baoToken, bytes32 _merkleRoot, address _treasury) {
        baoToken = _baoToken;
        merkleRoot = _merkleRoot;
        treasury = _treasury;
    }

    // -------------------------------
    // PUBLIC FUNCTIONS
    // -------------------------------

    /**
     * Starts the distribution of BAO for msg.sender.
     *
     * @param _proof Merkle proof to verify msg.sender's inclusion and claimed amount.
     * @param _amount Amount of tokens msg.sender is owed. Used to generate the merkle tree leaf.
     */
    function startDistribution(bytes32[] memory _proof, uint256 _amount) external {
        require(distributions[msg.sender].dateStarted == 0, "ERROR: Distribution already started");
        require(verifyProof(_proof, keccak256(abi.encodePacked(msg.sender, _amount))), "ERROR: Invalid proof");

        // This is artificial for now.
        uint64 _now = uint64(block.timestamp);
        distributions[msg.sender] = DistInfo(
            _now,
            0,
            _now,
            _amount
        );
        emit DistributionStarted(msg.sender);
    }

    /**
     * Claim all tokens that have been accrued since msg.sender's last claim.
     */
    function claim() external nonReentrant {
        uint256 _claimable = claimable(msg.sender, 0);
        require(_claimable > 0, "ERROR: Nothing to claim");

        // Update account's DistInfo
        distributions[msg.sender].lastClaim = uint64(block.timestamp);

        // TODO- Are we going to premint all owed tokens (this number is known), or are we going to mint them as they are issued?
        baoToken.transfer(msg.sender, _claimable);

        // Emit tokens claimed event for logging
        emit TokensClaimed(msg.sender, _claimable);
    }

    /**
     * Claim all tokens that have been accrued since msg.sender's last claim AND
     * the rest of the total locked amount owed immediately at a pre-defined slashed rate.
     * Rate: ((1 - daysSinceStart / 730) * 100)% of remaining distribution
     */
    function endDistribution() external nonReentrant {
        uint256 _claimable = claimable(msg.sender, 0);
        require(_claimable > 0, "ERROR: Nothing to claim");

        DistInfo storage distInfo = distributions[msg.sender];
        uint64 timestamp = uint64(block.timestamp);

        uint256 daysSinceStart = FixedPointMathLib.mulDivDown(uint256(timestamp - distInfo.dateStarted), 1e18, 86400);

        // Calculate total tokens left in distribution after the above claim
        uint256 tokensLeft = distInfo.amountOwedTotal - distCurve(distInfo.amountOwedTotal, daysSinceStart);

        // Calculate slashed amount
        uint256 slash = FixedPointMathLib.mulDivDown(
            1e18 - FixedPointMathLib.mulDivDown(daysSinceStart, 1e18, 730e18),
            tokensLeft,
            1e18
        );
        uint256 owed = tokensLeft - slash;

        // Account gets slashed for ((1 - daysSinceStart / 730) * 100)% of their remaining distribution
        baoToken.transfer(msg.sender, owed + _claimable);
        // Main-net treasury receives slashed tokens
        baoToken.transfer(treasury, slash);

        // Update DistInfo storage for account to reflect the end of the account's distribution
        distInfo.lastClaim = timestamp;
        distInfo.dateEnded = timestamp;

        // Emit tokens claimed event for logging
        emit TokensClaimed(msg.sender, _claimable);
        // Emit distribution ended event for logging
        emit DistributionEnded(msg.sender, owed);
    }

    /**
     * Get how many tokens an account is able to claim at a given timestamp. 0 = now.
     * This function takes into account the date of the account's last claim, and returns the amount
     * of tokens they've accrued since.
     *
     * @param _account Account address to query.
     * @param _timestamp Timestamp to query.
     * @return c _account's claimable tokens, scaled by 1e18.
     */
    function claimable(address _account, uint64 _timestamp) public view returns (uint256 c) {
        DistInfo memory distInfo = distributions[_account];
        require(distInfo.dateStarted != 0, "ERROR: Address unknown");
        require(distInfo.dateEnded == 0, "ERROR: Ended distribution early");

        uint64 timestamp = _timestamp == 0 ? uint64(block.timestamp) : _timestamp;
        require(timestamp >= distInfo.dateStarted, "ERROR: Timestamp invalid");

        uint256 daysSinceStart = FixedPointMathLib.mulDivDown(uint256(timestamp - distInfo.dateStarted), 1e18, 86400);
        uint256 daysSinceClaim = FixedPointMathLib.mulDivDown(uint256(timestamp - distInfo.lastClaim), 1e18, 86400);

        // Allow the account to claim all tokens accrued since the last time they've claimed.
        uint256 _total = distInfo.amountOwedTotal;
        c = distCurve(_total, daysSinceStart) - distCurve(_total, daysSinceStart - daysSinceClaim);
    }

    /**
     * Get the amount of tokens that would have been accrued along the distribution curve, assuming _daysSinceStart
     * days have passed and the account has never claimed.
     *
     * f(x) =
     * 0 <= x <= 100 : 0.03065x
     * 100 < x <= 730 : 0.000199914x^2 - 0.0120641x + 2.2727
     *
     * @param _amountOwedTotal Total amount of tokens owed, scaled by 1e18.
     * @param _daysSinceStart Time since the start of the distribution, scaled by 1e18.
     * @return uint256 Amount of tokens accrued on the distribution curve, assuming the time passed is _daysSinceStart.
     */
    function distCurve(uint256 _amountOwedTotal, uint256 _daysSinceStart) public pure returns (uint256) {
        return _daysSinceStart >= 730e18 ? _amountOwedTotal : FixedPointMathLib.mulDivDown(
            _amountOwedTotal,
            _daysSinceStart > 1e20 // Function goes from linear to parabolic at day 101
            ? (FixedPointMathLib.mulDivDown(
            199914,
                FixedPointMathLib.mulDivDown(_daysSinceStart, _daysSinceStart, 1e18),
                1e9
            ) - FixedPointMathLib.mulDivDown(120641, _daysSinceStart, 1e7) + 22727e14) / 1e2
            : FixedPointMathLib.mulDivDown(3065, _daysSinceStart, 1e7),
            1e18
        );
    }

    // -------------------------------
    // PRIVATE FUNCTIONS
    // -------------------------------

    /**
     * Verifies a merkle proof against the stored root.
     *
     * @param _proof Merkle proof.
     * @param _leaf Leaf to verify.
     * @return bool True if proof is valid, false if proof is invalid.
     */
    function verifyProof(bytes32[] memory _proof, bytes32 _leaf) private view returns (bool) {
        return MerkleProof.verify(_proof, merkleRoot, _leaf);
    }
}
