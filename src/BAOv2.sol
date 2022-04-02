// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./MultichainV7ERC20.sol";

//Multichain standard ERC20 with minting and Burning permissions, also admin/internal access as of now
//Add in the ability to optionaly upgrade to using layer0 network if we finesse a BAO Chainlink oracle down the line?

//underlying ERC20
contract BaoV2Token is MultichainV7ERC20 {
    using SafeERC20 for IERC20;

    address public immutable override underlying;

    event Deposit(address indexed from, address indexed to, uint256 amount);
    event Withdraw(address indexed from, address indexed to, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _cap,
        address _admin,
        address _underlying
    ) MultichainV7ERC20(_name, _symbol, _decimals, _cap, _admin) { //BaoToken, BAO, 18, 1Bill, admin address
        require(_underlying != address(0), "underlying is the zero address");
        require(_underlying != address(this), "underlying is same to address(this)");
        require(_decimals == IERC20Metadata(_underlying).decimals(), "decimals mismatch");

        underlying = _underlying;
    }

    function deposit(uint256 amount) public returns (uint256) {
        return deposit(amount, msg.sender);
    }

    function deposit(uint256 amount, address to) public returns (uint256) {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);
        _mint(to, amount);
        emit Deposit(msg.sender, to, amount);
        return amount;
    }

    function withdraw(uint256 amount) public returns (uint256) {
        return withdraw(amount, msg.sender);
    }

    function withdraw(uint256 amount, address to) public returns (uint256) {
        _burn(msg.sender, amount);
        IERC20(underlying).safeTransfer(to, amount);
        emit Withdraw(msg.sender, to, amount);
        return amount;
    }
}
