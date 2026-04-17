// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IVault {
    function getPoolTokens(bytes32 poolId)
        external
        view
        returns (address[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock);
}

interface IVotingEscrow {
    struct LockedBalance {
        int128 amount;
        uint256 end;
    }
    function locked(address user) external view returns (LockedBalance memory);
}

/// @title BAL voting power aggregator for the `balancer.eth` Snapshot space
/// @notice Returns a voter's voting power denominated in BAL, summing raw BAL, the BAL underlying the 80/20 BAL/WETH BPT, and the BAL underlying any BPT locked in veBAL.
/// @dev veBAL decay is ignored. Delegation is handled by the Snapshot composite strategy wrapping this contract, not onchain.
contract BalVotingPower {
    IERC20 public constant BAL = IERC20(0xba100000625a3754423978a60c9317c58a424e3D);
    IERC20 public constant BPT = IERC20(0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56);
    IVault public constant VAULT = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IVotingEscrow public constant VE_BAL = IVotingEscrow(0xC128a9954e6c874eA3d62ce62B468bA073093F25);

    bytes32 public constant POOL_ID = 0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014;

    uint256 private constant BAL_IDX = 0;

    function votingPower(address user) external view returns (uint256) {
        uint256 raw = BAL.balanceOf(user);

        int128 lockedAmt = VE_BAL.locked(user).amount;
        uint256 lockedBpt = lockedAmt > 0 ? uint256(uint128(lockedAmt)) : 0;

        uint256 totalBpt = BPT.balanceOf(user) + lockedBpt;
        uint256 fromBpt = totalBpt == 0 ? 0 : _bptToBal(totalBpt);

        return raw + fromBpt;
    }

    function _bptToBal(uint256 bptAmount) internal view returns (uint256) {
        (, uint256[] memory balances,) = VAULT.getPoolTokens(POOL_ID);
        return (bptAmount * balances[BAL_IDX]) / BPT.totalSupply();
    }
}
