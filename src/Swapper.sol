import "./ERC20BAO.vy";
import "solmate/tokens/ERC20.sol";
import "solmate/utils/ReentrancyGuard.sol";

contract Swapper is ReentrancyGuard {
    ERC20 public immutable baoV1;
    ERC20BAO public baov2;

    constructor(ERC20BAO _baov2) {
        // BaoV1 Token is a hardcoded constant
        baoV1 = ERC20(0x374CB8C27130E2c9E04F44303f3c8351B9De61C1);
        baov2 = _baov2;
    }

    function convertV1(uint256 _amount) public nonReentrant {
        baoV1.transferFrom(msg.sender, address(0), _amount); // Burn BAOV1
        baov2.mint(msg.sender, _amount / 1000); // BaoV2's supply is reduced by a factor of 1000
    }

}