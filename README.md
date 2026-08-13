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
4. Commit the broadcast log alongside those two changes.
5. Apply the file to the `balancer.eth` space settings.

## A note on editing the contract

`src/BalVotingPower.sol` is byte-locked to whatever is currently deployed. It is the only file in the contract's
compilation unit, and the compiler puts a hash of it into the bytecode. So editing it at all, even just a comment,
produces different bytecode from the deployed contract, and the address in `snapshot/balancer.eth.json` then
points at something this repo no longer builds.

`test_deployedV2MatchesConfigAndSource` asserts that it does still build it, so an edit shows up as a failing
test rather than as a silent divergence. If the change is wanted, follow the deploy steps above and update the
config address. If it is not, revert the edit.

Nothing else in the repo is covered by this. The tests, the workflow, this README, and the Snapshot config are
all outside the compilation unit and can be changed freely.
