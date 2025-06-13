# NFT Voting System

Blockchain-based voting system for MPs with NFT identity verification and staking

## Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Setup

```bash
git clone <repository-url>
cd nft-voting-project
forge install
forge build
```

## Testing

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv
```

## Local Development

```bash
# Terminal 1: Start blockchain
anvil

# Terminal 2: Deploy contracts
forge script script/Deploy.sol:DeployMPTokenFactory --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Deploy voting contract  
forge script script/DeployMPVoting.sol:DeployMPVoting --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Setup test data
forge script script/CreateMPTokensForAnvil.sol:CreateMPTokensForAnvil --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## Environment Variables

Create `.env`:
```bash
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
FACTORY_ADDRESS=0x...
VOTING_ADDRESS=0x...
```

## Basic Usage

### Vote with 100 ETH stake
```bash
cast send $VOTING_ADDRESS "vote(uint256,uint256)" 1 0 --value 100ether --private-key $MP_PRIVATE_KEY --rpc-url $RPC_URL
```

### Check vote status
```bash
cast call $VOTING_ADDRESS "checkVote(uint256,address)" 1 $MP_ADDRESS --rpc-url $RPC_URL
```

### Close voting (admin only)
```bash
cast send $VOTING_ADDRESS "closeQuestion(uint256)" 1 --private-key $ADMIN_PRIVATE_KEY --rpc-url $RPC_URL
```

### Claim stake back
```bash
cast send $VOTING_ADDRESS "claimStake(uint256)" 1 --private-key $MP_PRIVATE_KEY --rpc-url $RPC_URL
```

## Staking Rules
- **Winners**: Get 100% stake back
- **Losers**: Get 50% stake back
- **Vault**: Question creator gets remaining 50% from losers

## Project Structure

```
src/
├── MPToken.sol           # ERC721 MP identity tokens
├── MPTokenFactory.sol    # Factory for MP tokens  
└── MPVoting.sol          # Voting contract with staking
test/
└── MPVoting.t.sol        # Tests
script/
├── Deploy.sol            # Deployment scripts
├── DeployMPVoting.sol    # Voting deployment
└── CreateMPTokensForAnvil.sol # Local test setup
```
