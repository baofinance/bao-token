pragma solidity ^0.8.10;

import "@openzeppelin/access/AccessControlEnumerable.sol"; //give and take access + see what addresses have which roles
import "@openzeppelin/token/ERC20/extensions/ERC20Capped.sol";
import "solmate/utils/ReentrancyGuard.sol";

contract BaoToken is ERC20Capped, AccessControlEnumerable, ReentrancyGuard {
    // -- EIP712 --
    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,uint256 chainId,address verifyingContract,bytes32 salt)"
    );
    bytes32 private constant DOMAIN_VERSIONHASH = keccak256("1");
    bytes32 private constant DOMAIN_SALT = 0xfff6c856a1f2b4269a1d1d9bacd121f1c9273b6650961875824ce18cfc2ed86e;
    bytes32 private DOMAIN_SEPARATOR; // defined by constructor

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public constant MAX_SUPPLY = 15e26; // 1.5 billion

    ERC20 public baoV1;

    constructor(
        string memory _name, // Bao Finance
        string memory _symbol // BAO
    ) ERC20(_name, _symbol) ERC20Capped(MAX_SUPPLY) {
        address msgSender = msg.sender;
        // Grant roles to addresses
        _setupRole(DEFAULT_ADMIN_ROLE, msgSender);
        _setupRole(MINTER_ROLE, msgSender);

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

        baoV1 = ERC20(0x374CB8C27130E2c9E04F44303f3c8351B9De61C1);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        // internal virtual overide check in ERC20Capped.sol to make sure cap is not exceeded
        _mint(to, amount);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function convertV1(uint256 _amount) public nonReentrant {
        baoV1.transferFrom(msg.sender, address(0), _amount); // Burn BAOV1
        mint(msg.sender, _amount / 1e4); // BaoV2's max supply is reduced by a factor of 1000
    }
}
