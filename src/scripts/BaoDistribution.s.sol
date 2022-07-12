pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import "../BaoDistribution.sol";
import "../IVotingEscrow.sol";

contract MyScript is Script {
    function run() external {
        vm.startBroadcast();
        IERC20 baoToken;
        IVotingEscrow votingEscrow;
        bytes32 merkleRoot;
        address treasury;

        BaoDistribution distr = new BaoDistribution(baoToken, votingEscrow , merkleRoot, treasury);

        vm.stopBroadcast();
    }
}