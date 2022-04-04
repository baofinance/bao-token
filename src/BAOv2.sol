pragma solidity ^0.8.10;

//import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/access/AccessControlEnumerable.sol";
import "@openzeppelin/token/ERC20/extensions/ERC20Capped.sol";

contract BaoToken is ERC20Capped, AccessControlEnumerable {
    uint8 immutable _tokenDecimals;
    uint256 private _cap = 15000000000e18;
    //permissions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 mintLimit = 15000000e18; // single limit of each mint
    uint256 burnLimit = 15000000e18; // single limit of each burn

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
        // Grant roles to addresses
        _tokenDecimals = _decimals;
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(MINTER_ROLE, _admin);
        _setupRole(BURNER_ROLE, _admin);
        //mint 0 tokens
        _mint(msg.sender, 0);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require((totalSupply() + amount) <= _cap, "cap exceeded");
        require(amount <= mintLimit, "max mint exceeded");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        require(amount <= burnLimit, "max burn exceeded");
        _burn(from, amount);
    }
}
