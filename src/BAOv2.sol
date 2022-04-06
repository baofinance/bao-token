pragma solidity ^0.8.10;

import "@openzeppelin/access/AccessControlEnumerable.sol"; //give and take access + see what addresses have which roles
import "@openzeppelin/token/ERC20/extensions/ERC20Capped.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Capped.sol"; //define immutable cap

contract BaoToken is ERC20Capped, AccessControlEnumerable {
    // -- EIP712 --
    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,uint256 chainId,address verifyingContract,bytes32 salt)"
    );
    bytes32 private constant DOMAIN_VERSIONHASH = keccak256("1");
    bytes32 private constant DOMAIN_SALT = 0xfff6c856a1f2b4269a1d1d9bacd121f1c9273b6650961875824ce18cfc2ed86e;
    bytes32 private DOMAIN_SEPARATOR; //defined by constructor

    //permissions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 internal burnLimit = 15000000e18; // single limit of each burn

    constructor(
        string memory _name, //BaoToken
        string memory _symbol, //BAO
        uint256 cap,
        address _admin
    )
    ERC20(_name, _symbol)
    ERC20Capped(cap)
    {
        // Grant roles to addresses
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(MINTER_ROLE, _admin);
        _setupRole(BURNER_ROLE, _admin);

        // EIP-712 domain separator
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                DOMAIN_VERSIONHASH,
                block.chainid,
                address(this),
                DOMAIN_SALT
            )
        );

        //mint 0 tokens
        _mint(msg.sender, 0);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        //internal virtual overide check in ERC20Capped.sol to make sure cap is not exceeded
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        require(amount <= burnLimit, "max burn exceeded");
        _burn(from, amount);
    }
}
