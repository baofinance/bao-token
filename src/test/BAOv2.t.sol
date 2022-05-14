// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "ds-test/test.sol";
import "../BAOv2.sol";

interface Cheats {
    function warp(uint256) external;
    function startPrank(address) external;
    function stopPrank() external;
    function assume(bool) external;
}

contract ContractTest is DSTest {

    Cheats public cheats;
    BaoToken public baoToken;

    function setUp() public {
        cheats = Cheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        baoToken = new BaoToken(
            "Bao Finance",
            "BAO"
        );

    }

    function testInitSupply() public {
        assertEq(baoToken.INITIAL_SUPPLY(), baoToken.totalSupply());
    }

    function testMiningEpochStart() public {
        assertEq(baoToken.mining_epoch(), -1);
    }

    function testRateStart() public {
        assertEq(baoToken.rate(), 0);
    }

    function testSetMinter() public {
        baoToken.setMinter(address(this));
        assertEq(baoToken.minter(), address(this));
    }

    function testFailSetMinter() public {
        address caller = address(0);
        cheats.startPrank(caller);
        baoToken.setMinter(address(this));
        cheats.stopPrank();
    }

    function testUpdate_mining_parameters() public {
        cheats.warp(block.timestamp + 1 days);
        baoToken.update_mining_parameters();
        assertEq(baoToken.INITIAL_RATE(), baoToken.rate());
        assertEq(baoToken.mining_epoch(), 0);
        assertEq(baoToken.totalSupply(), baoToken.available_supply());
    }

    function testFailPrank_update_mining_parameters() public {
        address caller = address(0);
        cheats.startPrank(caller);
        baoToken.update_mining_parameters();
        cheats.stopPrank();
        assertEq(baoToken.rate(), 0);
        assertEq(baoToken.mining_epoch(), -1);
    }

    function testFail_update_mining_parameters_twice() public {
        cheats.warp(block.timestamp + 1 days);
        baoToken.update_mining_parameters();
        baoToken.update_mining_parameters();
        assertEq(baoToken.rate(), 0);
        assertEq(baoToken.mining_epoch(), -1);
    }

    //more to be done in testing update mining parameters
    //perhaps fuzz testing different timestamp scenarios?
    //idk what else

    function testMint() public {
        baoToken.mint(address(this), 1);
        assertEq(baoToken.totalSupply(), (15e26 + 1));
    }

    //more tests to add for minting

    function testFailPrankMint() public {
        address caller = address(0);
        cheats.startPrank(caller);
        baoToken.mint(address(this), 1);
        cheats.stopPrank();
        assertEq(baoToken.totalSupply(), baoToken.INITIAL_SUPPLY());
    }

    function testBurn() public {
        uint256 burnAmount = 1;
        baoToken.burn(burnAmount);
        assertEq(baoToken.totalSupply(), (baoToken.INITIAL_SUPPLY() - 1));
    }

    function testFailPrankBurn() public {
        address caller = address(0);
        cheats.startPrank(caller);
        baoToken.burn(1);
        cheats.stopPrank();
        assertEq(baoToken.totalSupply(), baoToken.INITIAL_SUPPLY());
    }




}
