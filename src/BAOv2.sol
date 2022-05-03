// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";
import "solmate/utils/ReentrancyGuard.sol";

contract BaoToken is ERC20, ReentrancyGuard {

    // --Events --
    event UpdateMiningParameters(uint256 time, uint256 rate, uint256 supply);
    event SetMinter(address minter);

    //uint256 public constant MAX_SUPPLY = 15e26; //1.5 billion
    ERC20 public immutable baoV1;
    address public minter;

    error MintExceedsMaxSupply();

    /*
    * with these numbers below, all BAOv1 addresses from the distribution get access to right under 50% of total
    * emissions as time -> infinity (can easily change this to resemble curve if we want
    */
    uint256 public constant INITIAL_SUPPLY = 15e26; // 1.5B, will need to be exact once farms stop, ~1.5B but not exactly
    uint256 public constant INITIAL_RATE = 871433545e18; //pre-mine currently at ~49.5% as a test (curve pre-mine = ~43%)
    uint256 public constant RATE_REDUCTION_TIME = 365 days;
    uint256 public constant RATE_REDUCTION_COEFFICIENT = 1189207115002721024; //2 ** (1/4) * 1e18, emissions function
    uint256 public constant RATE_DENOMINATOR = 10 ** 18;
    uint256 public constant INFLATION_DELAY = 1 days;

    //supply variables
    int128 public mining_epoch;
    uint256 public start_epoch_time;
    uint256 public rate;
    uint256 start_epoch_supply;

    modifier onlyMinter {
        require(msg.sender == minter);
        _;
    }

    constructor(
        string memory _name, // Bao Finance
        string memory _symbol // BAO
    ) ERC20(_name, _symbol, 18) {
        minter = msg.sender;
        mint(minter, INITIAL_SUPPLY); //pre-mint using 1.5B for now
        start_epoch_time = block.timestamp + INFLATION_DELAY - RATE_REDUCTION_TIME;
        mining_epoch = -1;
        rate = 0;
        start_epoch_supply = INITIAL_SUPPLY;

        // BaoV1 Token is a hardcoded constant
        baoV1 = ERC20(0x374CB8C27130E2c9E04F44303f3c8351B9De61C1);
    }

    function setMinter(address _address) public onlyMinter {
        minter = _address;
    }

    /*
    * @dev Update mining rate and supply at the start of the epoch
    * Any modifying mining call must also call this
    */
    function _update_mining_parameters() internal {
        uint256 _rate = rate;
        uint256 _start_epoch_supply = start_epoch_supply;

        start_epoch_time += RATE_REDUCTION_TIME;
        mining_epoch += 1;

        if(_rate == 0) {
            _rate = INITIAL_RATE;
        }
        else {
            _start_epoch_supply += _rate * RATE_REDUCTION_TIME;
            start_epoch_supply = _start_epoch_supply;
            _rate = _rate * RATE_DENOMINATOR / RATE_REDUCTION_COEFFICIENT;
        }
        rate = _rate;
        emit UpdateMiningParameters(block.timestamp, _rate, _start_epoch_supply);
    }

    /*
    * @notice Update mining rate and supply at the start of the epoch
    * @dev Callable by any address, but only once per epoch
    * Total supply becomes slightly larger if this function is called late
    */
    function update_mining_parameters() external {
        require(block.timestamp >= start_epoch_time + RATE_REDUCTION_TIME);
        _update_mining_parameters();
    }

    /*
    * @notice Get timestamp of the current mining epoch start while simultaneously updating mining parameters
    * @return Timestamp of the epoch
    */
    function start_epoch_time_write() external returns(uint256) {
        uint256 _start_epoch_time = start_epoch_time;
        if(block.timestamp >= _start_epoch_time) {
            _update_mining_parameters();
            return start_epoch_time;
        }
        else {
            return start_epoch_time;
        }
    }

    /*
    * @notice Get timestamp of the next mining epoch start while simultaneously updating mining parameters
    * @return Timestamp of the next epoch
    */
    function future_epoch_time_write() external returns(uint256) {
        uint256 _start_epoch_time = start_epoch_time;
        if(block.timestamp >= _start_epoch_time + RATE_REDUCTION_TIME) {
            _update_mining_parameters();
            return start_epoch_time + RATE_REDUCTION_TIME;
        }
        else {
            return start_epoch_time + RATE_REDUCTION_TIME;
        }
    }

    function _available_supply() internal view returns(uint256) {
        return start_epoch_supply + (block.timestamp - start_epoch_time) * rate;
    }

    /*
    * @notice Current number of tokens in existence (claimed or unclaimed)
    */
    function available_supply() external view returns(uint256) {
        return _available_supply();
    }

    /*
    * @notice How much supply is mintable from start timestamp till end timestamp
    * @param start Start of the time interval (timestamp)
    * @param end End of the time interval (timestamp)
    * @return Tokens mintable from `start` till `end`
    */
    function mintable_in_timeframe(uint256 start, uint256 end) external view returns(uint256) {
        require(start <= end);
        uint256 to_mint = 0;
        uint256 current_epoch_time = start_epoch_time;
        uint256 current_rate = rate;

        //Special case if end is in future (not yet minted) epoch
        if(end > current_epoch_time + RATE_REDUCTION_TIME) {
            current_epoch_time += RATE_REDUCTION_TIME;
            current_rate = current_rate * RATE_DENOMINATOR / RATE_REDUCTION_COEFFICIENT;
        }

        require(end <= current_epoch_time + RATE_REDUCTION_TIME);

        for(int i = 0; i <= 999; i++) { //stops working past 999+ years
            if(end >= current_epoch_time) {
                uint256 current_end = end;
                if(current_end > current_epoch_time + RATE_REDUCTION_TIME) {
                    current_end = current_epoch_time + RATE_REDUCTION_TIME;
                }
                uint256 current_start = start;
                if(current_start >= current_epoch_time + RATE_REDUCTION_TIME) {
                    break;
                }
                else if(current_start < current_epoch_time) {
                    current_start = current_epoch_time;
                }
                to_mint += current_rate * (current_end - current_start);
                if(start >= current_epoch_time) {
                    break;
                }
            }

            current_epoch_time -= RATE_REDUCTION_TIME;
            current_rate = current_rate * RATE_REDUCTION_COEFFICIENT / RATE_DENOMINATOR;
            require(current_rate <= INITIAL_RATE);
        }
        return to_mint;
    }

    function mint(address to, uint256 amount) public onlyMinter {
        //if (totalSupply + amount >= MAX_SUPPLY) {
        //    revert MintExceedsMaxSupply();
        //}
        _mint(to, amount);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function convertV1(uint256 _amount) public nonReentrant {
        baoV1.transferFrom(msg.sender, address(0), _amount); // Burn BAOV1
        mint(msg.sender, _amount / 1e4); // BaoV2's supply is reduced by a factor of 10,000
    }
}
