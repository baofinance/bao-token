pragma solidity ^0.8.10;

import "@openzeppelin/access/AccessControlEnumerable.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";
import "solmate/utils/ReentrancyGuard.sol";

contract BaoToken is AccessControlEnumerable, ReentrancyGuard, ERC20 {
    // --Events --
    event UpdateMiningParameters(uint256 time, uint256 rate, uint256 supply);
    event setMinter(address minter);

    address public minter;

    // -- EIP712 --
    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,uint256 chainId,address verifyingContract,bytes32 salt)"
    );
    bytes32 private constant DOMAIN_VERSIONHASH = keccak256("1");
    bytes32 private constant DOMAIN_SALT = 0xfff6c856a1f2b4269a1d1d9bacd121f1c9273b6650961875824ce18cfc2ed86e;
    bytes32 private DOMAIN_SEPARATOR; // defined by constructor

    /*
    * with these numbers below, all BAOv1 addresses from the distribution get access to right under 50% of total
    * emissions as time -> infinity (can easily change this to resemble curve if we want
    */
    uint256 public constant INITIAL_SUPPLY = 15e26; // 1.5 billion
    uint256 public constant INITIAL_RATE = 871433545e18; //pre-mine currently at ~49.5% as a test (curve pre-mine = ~43%)
    uint256 public constant RATE_REDUCTION_TIME = 365 days;
    uint256 public constant RATE_REDUCTION_COEFFICIENT = 1189207115002721024; //2 ** (1/4) * 1e18
    uint256 public constant RATE_DENOMINATOR = 10 ** 18;
    uint256 public constant INFLATION_DELAY = 1 days;


    ERC20 public baoV1;

    constructor(
        string memory _name, // Bao Finance
        string memory _symbol // BAO
    ) ERC20(_name, _symbol) {
        address msgSender = msg.sender;
        // Grant roles
        _setupRole(DEFAULT_ADMIN_ROLE, msgSender);
        //set_minter(address(dedicated minter contract));

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

    function set_minter(address _minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(minter == address(0)); //callable only once
        minter = _minter;
        emit setMinter(_minter);
    }

    //function _update_mining_parameters() internal {}
    //function update_mining_parameters() external {}

    //function start_epoch_time_write() external returns(uint256) {}

    //function future_epoch_time_write() external returns(uint256) {}

    //function _available_supply() internal returns(uint256)
    //function available_supply() external returns(uint256)

    //function mintable_in_timeframe(uint256 start, uint256 end) external returns(uint256)

    function mint(address to, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(to, amount);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function convertV1(uint256 _amount) public nonReentrant {
        baoV1.transferFrom(msg.sender, address(0), _amount); // Burn BAOV1
        mint(msg.sender, _amount / 1e4); // BaoV2's supply is reduced by a factor of 1000
    }
}
