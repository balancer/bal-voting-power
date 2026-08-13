# bal-voting-power

Ethereum aggregator contract for $BAL voting power and config for the `balancer.eth` Snapshot space.

## Dev

```bash
cp .env.example .env # set ETH_RPC_URL and ETHERSCAN_API_KEY
forge soldeer install
forge test
```

## Deploy

Dry-run the deployment first:

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url mainnet \
  --sender 0xAddressOfDeployer
```

Broadcast and verify on Etherscan:

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url mainnet \
  --sender 0xAddressOfDeployer \
  --broadcast \
  --verify \
  --verifier etherscan \
  --etherscan-api-key "$ETHERSCAN_API_KEY"
```

Then point the Snapshot space at the new deployment:

1. Copy the deployed address from the broadcast log at `broadcast/Deploy.s.sol/1/run-<timestamp>.json`, under
   `returns.deployed.value`.
2. Put it in `snapshot/balancer.eth.json`, under `strategies[0].params.strategies[0].params.address`.
3. Put it in `test/BalVotingPower.t.sol`, as `DEPLOYED_V2`, and set `V2_DEPLOY_BLOCK` to the block the broadcast
   log records under `receipts[0].blockNumber`.
4. Set `DEPLOYED_SOURCE_HASH` in the same file to `keccak256` of the contract source as deployed:
   `cat src/BalVotingPower.sol | cast keccak`. Pipe it rather than passing `"$(cat ...)"` as an argument, which
   drops the trailing newline and gives a different hash.
5. Commit the broadcast log alongside those changes.
6. Apply the file to the `balancer.eth` space settings.

## A note on editing the contract

`src/BalVotingPower.sol` is byte-locked to whatever is currently deployed. It is the only file in the contract's
compilation unit, and the compiler appends a hash of it to the bytecode. So editing it at all, even just a
comment, produces different bytecode from the deployed contract, and the address in `snapshot/balancer.eth.json`
then points at something this repo no longer builds. If you change that file, follow the deploy steps above and
update the address.

Two tests hold that rule between them.

`test_sourceIsUnchangedSinceDeployment` hashes the source file and compares it against `DEPLOYED_SOURCE_HASH`,
which is the hash the deployed contract's own metadata records for it. Any edit fails this, a comment included.
It needs no compiler and no RPC, so it gives the same answer on every machine.

`test_deployedV2MatchesConfigAndSource` checks the other direction: that the config address, the `DEPLOYED_V2`
constant, and the executable code this repo builds all agree. It stops short of the metadata appended after the
executable code, because that hash depends on the build environment and comes out different on CI than it does
locally. The source-hash test is what covers that gap.

Nothing else in the repo is covered by any of this. The tests, the workflow, this README, and the Snapshot
config are all outside the compilation unit and can be changed freely.
