pragma solidity 0.8.13;

interface IVotingEscrow {
    function create_lock_for(address _to, uint256 _value, uint256 _unlock_time) external;
}