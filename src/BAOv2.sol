// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "@openzeppelin/access/AccessControlEnumerable.sol";
import "@openzeppelin/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
//import "@openzeppelin/token/ERC20/extensions/ERC20Pausable.sol"; ?

contract BaoV2Token is ERC20Capped, ERC20Burnable, AccessControlEnumerable {
    //permissions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); //mint+burn privilege
    bytes32 public constant DEFAULT_ADMIN_ROLE = keccak256("ADMIN"); //internal

    //Transfer and Approval events

    struct Supply {
        uint256 max; // single limit of each mint
        // variable here for total limit of all mint/cap
        uint256 total; // total minted minus burned
    }

    mapping(address => Supply) public minterSupply;

    // control mint and burn actions
    bool public allMintPaused; // pause all minters' mint calling
    bool public allBurnPaused; // pause all minters' burn calling (normal user is not paused)
    mapping(address => bool) public mintPaused; // pause specify minters' mint calling
    mapping(address => bool) public burnPaused; // pause specify minters' burn calling

    uint8 immutable _tokenDecimals; //18

    mapping(bytes32 => bool) public swapinExisted;

    event LogSwapin(bytes32 indexed txhash, address indexed account, uint256 amount);
    event LogSwapout(address indexed account, address indexed bindaddr, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _cap,
        address _admin
    )
    ERC20(_name, _symbol)
    ERC20Capped(_cap)
    {
        _tokenDecimals = _decimals;
        _grantRole(MINTER_ROLE, _minter);
        _grantRole(ADMIN, _admin);
        //define _cap?
    }

    //return admin address
    function getOwner() external view returns (address) {
        return getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }

    //function to return address(es) with minter role?

    function decimals() public view virtual override returns (uint8) {
        return _tokenDecimals;
    }

    function underlying() external view virtual returns (address) {
        return address(0);
    }

    //internal
    function _mint(address to, uint256 amount) internal virtual override(ERC20, ERC20Capped) onlyRole(MINTER_ROLE) {
        if (hasRole(MINTER_ROLE, msg.sender)) {
            require(to != address(this), "forbid mint to address(this)");
            require(!allMintPaused && !mintPaused[msg.sender], "mint paused");
            Supply storage s = minterSupply[msg.sender];
            require(amount <= s.max, "minter max exceeded");
            s.total += amount;
            require(s.total <= s.cap, "minter cap exceeded");
        }
        super._mint(to, amount);
    }

    //internal
    function _burn(address from, uint256 amount) internal virtual override onlyRole(MINTER_ROLE) {
        require(from != address(this), "forbid burn from address(this)");
        require(!allBurnPaused && !burnPaused[msg.sender], "burn paused");
        Supply storage s = minterSupply[msg.sender];
        require(s.total >= amount, "minter burn amount exceeded");
        s.total -= amount;

        super._burn(from, amount);
    }

    //external
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) returns (bool) {
        _mint(to, amount);
        return true;
    }

    //external
    function burn(address from, uint256 amount) external onlyRole(MINTER_ROLE) returns (bool) {
        _burn(from, amount);
        return true;
    }

    function Swapin(bytes32 txhash, address account, uint256 amount) external onlyRole(MINTER_ROLE) returns (bool) {
        require(!swapinExisted[txhash], "swapin existed");
        swapinExisted[txhash] = true;
        _mint(account, amount);
        emit LogSwapin(txhash, account, amount);
        return true;
    }

    function Swapout(uint256 amount, address bindaddr) external returns (bool) {
        require(bindaddr != address(0), "zero bind address");
        super._burn(msg.sender, amount);
        emit LogSwapout(msg.sender, bindaddr, amount);
        return true;
    }

    function addMinter(address minter, uint256 cap, uint256 max) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, minter);
        minterSupply[minter].cap = cap;
        minterSupply[minter].max = max;
        mintPaused[minter] = false;
        burnPaused[minter] = false;
    }

    function removeMinter(address minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, minter);
        minterSupply[minter].cap = 0;
        minterSupply[minter].max = 0;
    }

    function setMinterCap(address minter, uint256 cap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(MINTER_ROLE, minter), "not minter");
        minterSupply[minter].cap = cap;
    }

    function setMinterMax(address minter, uint256 max) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(MINTER_ROLE, minter), "not minter");
        minterSupply[minter].max = max;
    }

    function setMinterTotal(address minter, uint256 total, bool force) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(force || hasRole(MINTER_ROLE, minter), "not minter");
        minterSupply[minter].total = total;
    }

    function setAllMintPaused(bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allMintPaused = paused;
    }

    function setAllBurnPaused(bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allBurnPaused = paused;
    }

    function setAllMintAndBurnPaused(bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allMintPaused = paused;
        allBurnPaused = paused;
    }

    function setMintPaused(address minter, bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(MINTER_ROLE, minter), "not minter");
        mintPaused[minter] = paused;
    }

    function setBurnPaused(address minter, bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(MINTER_ROLE, minter), "not minter");
        burnPaused[minter] = paused;
    }

    function setMintAndBurnPaused(address minter, bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(MINTER_ROLE, minter), "not minter");
        mintPaused[minter] = paused;
        burnPaused[minter] = paused;
    }
}

//underlying ERC20
contract BAOv2ERC20WithUnderlying is BaoV2Token {
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
    ) BaoV2Token(_name, _symbol, _decimals, _cap, _admin) {
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
