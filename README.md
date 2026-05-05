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
