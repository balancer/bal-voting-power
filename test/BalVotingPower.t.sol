// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BalVotingPower} from "../src/BalVotingPower.sol";

contract BalVotingPowerTest is Test {
    BalVotingPower vp;

    // The live v1 deployment, used as the reference for "unchanged for everyone else".
    BalVotingPower constant DEPLOYED_V1 = BalVotingPower(0x411e723E6652347FF3Dd31749913A834e3D43DB4);

    // The live v2 deployment, and the block it was created in. This address is the one carried in
    // snapshot/balancer.eth.json, and test_deployedV2MatchesConfigAndSource asserts that the config file,
    // this constant, and the executable code this repo builds all agree.
    //
    // That comparison stops short of the compiler metadata appended after the code, because its hash comes out
    // different on CI than it does locally. test_sourceIsUnchangedSinceDeployment covers what it misses, by
    // hashing the source file directly.
    BalVotingPower constant DEPLOYED_V2 = BalVotingPower(0x8103325109cF67ACb97aEeCa5b976677A4FF5E82);
    uint256 constant V2_DEPLOY_BLOCK = 25_738_023;

    // keccak256 of src/BalVotingPower.sol exactly as it was compiled for DEPLOYED_V2, read out of that
    // contract's verified metadata under sources["src/BalVotingPower.sol"].keccak256. The compiler hashes the
    // source into the bytecode, so this is what makes an edit to that file a redeploy.
    bytes32 constant DEPLOYED_SOURCE_HASH = 0x5ab3ab2cf147751c8b6b4b807fdf82724fdfeaa36863a309e048cb0a6dd3d2a6;

    address constant AURA_VOTER_PROXY = 0xaF52695E1bB01A16D33D7194C28C42b10e0Dbec2;
    // Aura's Snapshot delegate safe. Holds nothing itself, so it must be unaffected onchain.
    address constant AURA_DELEGATE_SAFE = 0xAD9992f3631028CEF19e6D6C31e822C5bc2442CC;

    // Pinned so the fixtures stay valid. Aura's veBAL lock expires 2027-04-29, after which the BPT is
    // withdrawable and the balances these tests assert against will drain. It has to be at or after block
    // 25027601, where DEPLOYED_V1 was deployed.
    uint256 constant FORK_BLOCK = 25_700_000; // 2026-08-07

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
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

    /// @dev The position is material under the live v1 deployment, and zero here. The baseline is the figure
    ///      cited in BIP-924; update it alongside FORK_BLOCK if the pin moves.
    function test_auraVoterProxyIsZeroed() public view {
        assertEq(DEPLOYED_V1.votingPower(AURA_VOTER_PROXY), 18_012_789.472513897356804457e18, "v1 baseline");
        assertTrue(vp.isExcluded(AURA_VOTER_PROXY));
        assertEq(vp.votingPower(AURA_VOTER_PROXY), 0);
    }

    /// @dev Exclusion must survive the proxy acquiring liquid BAL or BPT on top of its lock.
    function test_auraVoterProxyStaysZeroedWithFreshBalance() public {
        deal(address(vp.BAL()), AURA_VOTER_PROXY, 1_000_000e18);
        deal(address(vp.BPT()), AURA_VOTER_PROXY, 1_000_000e18);
        assertEq(vp.votingPower(AURA_VOTER_PROXY), 0);
    }

    /// @dev Only the proxy is excluded. The delegate safe is scored normally; the composite strategy is what
    ///      stops it from receiving the proxy's (now zero) score.
    function test_delegateSafeIsNotExcluded() public view {
        assertFalse(vp.isExcluded(AURA_DELEGATE_SAFE));
        assertEq(vp.votingPower(AURA_DELEGATE_SAFE), DEPLOYED_V1.votingPower(AURA_DELEGATE_SAFE));
    }

    /// @dev Nobody else's score may change. Uses holders with a materially non-zero score, so the comparison
    ///      cannot pass vacuously the way a random address does.
    function test_matchesV1ForRealHolders() public view {
        address[2] memory holders = [
            0x9cC56Fa7734DA21aC88F6a816aF10C5b898596Ce, // TetuBAL locker, large veBAL lock
            0x89f67f3054bFD662971854190Dbc18dcaBb416f6 // VeBalGrant, lock expired but still counted
        ];

        for (uint256 i; i < holders.length; ++i) {
            uint256 expected = DEPLOYED_V1.votingPower(holders[i]);
            assertGt(expected, 0);
            assertEq(vp.votingPower(holders[i]), expected);
        }
    }

    /// @dev Guards against a future exclusion set matching more addresses than intended. Deliberately kept to
    ///      a low run count: every run is a fresh address, so none of its storage reads hit the fork cache.
    /// forge-config: default.fuzz.runs = 16
    function testFuzz_matchesV1ForNonExcluded(address user) public view {
        vm.assume(user != AURA_VOTER_PROXY);
        assertEq(vp.votingPower(user), DEPLOYED_V1.votingPower(user));
    }

    /// @dev The Snapshot config names a live address, so it has to be the contract this repo builds. Makes its
    ///      own fork, because FORK_BLOCK predates the v2 deployment and the address has no code there.
    function test_deployedV2MatchesConfigAndSource() public {
        string memory config = vm.readFile("snapshot/balancer.eth.json");
        address configured = vm.parseJsonAddress(config, ".strategies[0].params.strategies[0].params.address");
        assertEq(configured, address(DEPLOYED_V2), "config address");

        vm.createSelectFork("mainnet", V2_DEPLOY_BLOCK);
        BalVotingPower local = new BalVotingPower();
        bytes32 deployed = keccak256(_executableCode(address(DEPLOYED_V2)));
        assertEq(deployed, keccak256(_executableCode(address(local))), "executable code");
    }

    /// @dev Editing src/BalVotingPower.sol at all, a comment included, changes the deployed bytecode, because
    ///      the compiler hashes the source text into it. Hashing the file needs no compiler, so unlike a
    ///      bytecode comparison this gives the same answer on every machine.
    function test_sourceIsUnchangedSinceDeployment() public view {
        assertEq(keccak256(bytes(vm.readFile("src/BalVotingPower.sol"))), DEPLOYED_SOURCE_HASH, "source text");
    }

    /// @dev Returns the runtime code with its trailing CBOR metadata removed. That metadata holds a hash of the
    ///      source text and of the compiler settings, and it comes out different on CI than it does locally even
    ///      when the executable code is identical, so comparing whole runtime code is not portable.
    function _executableCode(address target) internal view returns (bytes memory) {
        bytes memory code = target.code;
        uint256 cborLength = (uint256(uint8(code[code.length - 2])) << 8) | uint256(uint8(code[code.length - 1]));

        bytes memory body = new bytes(code.length - cborLength - 2);
        for (uint256 i; i < body.length; ++i) {
            body[i] = code[i];
        }
        return body;
    }
}
