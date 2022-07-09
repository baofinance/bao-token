pragma solidity 0.8.15;

interface IERC20BAO {
    function mint(address _to, uint256 _value) external returns (bool);
}