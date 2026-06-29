// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BalVotingPower, IERC20, IVotingEscrow} from "../src/BalVotingPower.sol";

contract BalVotingPowerTest is Test {
    BalVotingPower vp;

    function setUp() public {
        vm.createSelectFork("mainnet");
        vp = new BalVotingPower();
    }

    function test_freshAddressHasNoPower() public {
        assertEq(vp.votingPower(makeAddr("nobody")), 0);
    }

    function test_rawBalHolder() public {
        address holder = makeAddr("bagholder");
        deal(address(vp.BAL()), holder, 1_000e18);
        assertEq(vp.votingPower(holder), 1_000e18);
    }

    function test_bptHolderScalesToBal() public {
        address holder = makeAddr("lp");
        deal(address(vp.BPT()), holder, 1e18);

        (, uint256[] memory balances,) = vp.VAULT().getPoolTokens(vp.POOL_ID());
        uint256 expected = (1e18 * balances[0]) / vp.BPT().totalSupply();

        assertEq(vp.votingPower(holder), expected);
    }

    function test_knownVeBalHolder() public view {
        // TetuBAL locker: locked().amount will always remain > 0
        address holder = 0x9cC56Fa7734DA21aC88F6a816aF10C5b898596Ce;
        uint256 power = vp.votingPower(holder);
        assertGt(power, 0);
    }
}
