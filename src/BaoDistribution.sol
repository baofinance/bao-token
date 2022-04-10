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

    // -------------------------------
    // CONSTANTS
    // -------------------------------

    bytes32 public immutable merkleRoot;

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

    event DistributionStarted(address _account);
    event TokensClaimed(address _account, uint256 _amount);

    /**
     * Create a new BaoDistribution contract.
     *
     * @param _baoToken Token to distribute.
     * @param _merkleRoot Merkle root to verify accounts' inclusion and amount owed when starting their distribution.
     */
    constructor(BaoToken _baoToken, bytes32 _merkleRoot) {
        baoToken = _baoToken;
        merkleRoot = _merkleRoot;
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
        uint64 now = uint64(block.timestamp);
        distributions[msg.sender] = DistInfo(
            now,
            now,
            _amount
        );
        emit DistributionStarted(msg.sender);
    }

    /**
     * Claim all tokens that have been accrued since msg.sender's last claim.
     */
    function claim() external nonReentrant {
        uint256 claimable = claimable(msg.sender, 0);
        require(claimable > 0, "ERROR: Nothing to claim");
        uint64 timestamp = uint64(block.timestamp);

        // Update account's DistInfo
        distributions[msg.sender].lastClaim = timestamp;

        baoToken.transfer(msg.sender, claimable);

        // Emit tokens claimed event for logging
        emit TokensClaimed(msg.sender, claimable);
    }

    /**
     * Get how many tokens an account is able to claim at a given timestamp. 0 = now.
     * This function takes into account the date of the account's last claim, and returns the amount
     * of tokens they've accrued since.
     *
     * @param _account Account address to query.
     * @param _timestamp Timestamp to query.
     */
    function claimable(address _account, uint64 _timestamp) public view returns (uint256 c) {
        DistInfo memory distInfo = distributions[_account];
        require(distInfo.dateStarted != 0, "ERROR: Address unknown");

        uint64 timestamp = _timestamp == 0 ? uint64(block.timestamp) : _timestamp;
        require(timestamp >= distInfo.dateStarted, "ERROR: Timestamp invalid");

        uint256 daysSinceStart = FixedPointMathLib.mulDivDown(uint256(timestamp - distInfo.dateStarted), 1e18, 86400);
        uint256 daysSinceClaim = FixedPointMathLib.mulDivDown(uint256(timestamp - distInfo.lastClaim), 1e18, 86400);

        // Allow the account to claim all tokens accrued since the last time they've claimed.
        c = distCurve(distInfo.amountOwedTotal, daysSinceStart) - distCurve(distInfo.amountOwedTotal, daysSinceStart - daysSinceClaim);
    }

    // -------------------------------
    // PRIVATE FUNCTIONS
    // -------------------------------

    /**
     * Get the amount of tokens that would have been accrued along the distribution curve assuming no
     * claims have been made.
     *
     * f(x) =
     * 0 <= x <= 100 : 0.03065x
     * 100 < x <= 730 : 0.000199914x^2 - 0.0120641x + 2.2727
     *
     * @param _amountOwedTotal Total amount of tokens owed, scaled by 1e18.
     * @param _daysSinceStart Time since the start of the distribution, scaled by 1e18.
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

    /**
     * Verifies a merkle proof against the stored root.
     *
     * @param _proof Merkle proof.
     * @param _leaf Leaf to verify.
     */
    function verifyProof(bytes32[] memory _proof, bytes32 _leaf) public view returns (bool) {
        return MerkleProof.verify(_proof, merkleRoot, _leaf);
    }
}