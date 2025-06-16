# MP NFT Voting System

Blockchain-based voting system for Members of Parliament using NFT identity verification and ETH staking mechanisms.

## Overview

This system enables secure voting by MPs through:
- NFT Identity Verification: Each MP receives a unique NFT token with their details
- Staking Mechanism: 100 ETH stake required per vote
- Transparent Results: All votes recorded on-chain
- Stake Distribution: Winners get full stake back, losers get 50% back (50% goes to vault)

## Prerequisites

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup

forge --version
cast --version
anvil --version
```

## Setup

```bash
git clone <repository-url>
cd Elections_NFT
forge install
forge build
```

## Local Development

### Terminal 1: Start blockchain
```bash
anvil
```

### Terminal 2: Deploy contracts
```bash
export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

# Deploy MP Token Factory
forge script script/Deploy.sol:DeployMPTokenFactory \
  --rpc-url http://localhost:8545 \
  --private-key $PRIVATE_KEY \
  --broadcast

# Set factory address
export FACTORY_ADDRESS="0x5FbDB2315678afecb367f032d93F642f64180aa3"

# Deploy Voting Contract
forge script script/DeployMPVoting.sol:DeployMPVoting \
  --rpc-url http://localhost:8545 \
  --private-key $PRIVATE_KEY \
  --broadcast

# Set voting address 
export VOTING_ADDRESS="0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"
```

## Voting Process

### 1. Check voting eligibility
```bash
cast call $VOTING_ADDRESS "isValidMPVoter(address)" $YOUR_ADDRESS \
  --rpc-url http://localhost:8545
```

### 2. Cast vote with stake
```bash
# Vote options: 0=Yes, 1=No, 2=Abstain
cast send $VOTING_ADDRESS "vote(uint256,uint256)" 1 0 \
  --value 100ether \
  --private-key $YOUR_PRIVATE_KEY \
  --rpc-url http://localhost:8545
```

### 3. Check voting results (after voting ends)
```bash
# Get detailed results
cast call $VOTING_ADDRESS "getDetailedVotingResults(uint256)" 1 \
  --rpc-url http://localhost:8545
```

### 4. Claim stake back
```bash
cast send $VOTING_ADDRESS "claimStake(uint256)" 1 \
  --private-key $YOUR_PRIVATE_KEY \
  --rpc-url http://localhost:8545
```

## Admin Functions

### Create new voting question
```bash
cast send $VOTING_ADDRESS "createQuestion(string,uint256,uint256)" \
  "Should we pass the new bill?" \
  $(date -d "+1 minute" +%s) \
  $(date -d "+1 hour" +%s) \
  --private-key $ADMIN_PRIVATE_KEY \
  --rpc-url http://localhost:8545
```

### Close voting
```bash
cast send $VOTING_ADDRESS "closeQuestion(uint256)" 1 \
  --private-key $ADMIN_PRIVATE_KEY \
  --rpc-url http://localhost:8545
```

### Create MP tokens
```bash
cast send $FACTORY_ADDRESS "createMPToken(address,string,string,string,uint256,uint256)" \
  $MP_ADDRESS \
  "John Smith" \
  "Conservative" \
  "Westminster North" \
  2024 \
  $(date -d "+4 years" +%s) \
  --private-key $ADMIN_PRIVATE_KEY \
  --rpc-url http://localhost:8545
```
## Useful Commands

### Check balances
```bash
cast balance $ADDRESS --rpc-url http://localhost:8545
```

### Get question details
```bash
cast call $VOTING_ADDRESS "getQuestionDetails(uint256)" 1 \
  --rpc-url http://localhost:8545
```

### Check vote counts
```bash
# Get Yes votes
cast call $VOTING_ADDRESS "getYesVotesCount(uint256)" 1 \
  --rpc-url http://localhost:8545

# Get No votes  
cast call $VOTING_ADDRESS "getNoVotesCount(uint256)" 1 \
  --rpc-url http://localhost:8545
```

### Check if you voted
```bash
cast call $VOTING_ADDRESS "checkVote(uint256,address)" 1 $YOUR_ADDRESS \
  --rpc-url http://localhost:8545
```

### Check stake status
```bash
cast call $VOTING_ADDRESS "getStakeInfo(uint256,address)" 1 $YOUR_ADDRESS \
  --rpc-url http://localhost:8545
```

## Demo with python script

Run complete voting simulation:
```bash
python3 voting_simulation.py
```

This script will:
- Deploy all contracts
- Create MP tokens for test accounts
- Create 4 voting questions (including one draw scenario)
- Simulate voting with different patterns
- Demonstrate stake claiming

## Testing

```bash
# Run all tests
forge test

# Run with detailed output
forge test -vvv

# Run specific test
forge test --match-test testVotingWithStakes -vvv

# Run tests with gas reporting
forge test --gas-report
```

## Environment Variables

Create `.env` file:
```bash
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
FACTORY_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
VOTING_ADDRESS=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
```

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

voting_simulation.py      # Complete demo simulation
```

## Troubleshooting

### Common Errors

**"Not a valid MP voter"**
```bash
cast call $FACTORY_ADDRESS "getMPTokenCount()" --rpc-url http://localhost:8545
cast call $FACTORY_ADDRESS "getMPTokenData(uint256)" 1 --rpc-url http://localhost:8545
```

**"Must stake exactly 100 ETH"**
```bash
cast send $VOTING_ADDRESS "vote(uint256,uint256)" 1 0 --value 100ether --private-key $KEY --rpc-url http://localhost:8545
```

**"Voting has not started yet"**
```bash
cast call "block.timestamp" --rpc-url http://localhost:8545
cast call $VOTING_ADDRESS "getQuestionDetails(uint256)" 1 --rpc-url http://localhost:8545
```

**"Already voted"**
```bash
cast call $VOTING_ADDRESS "checkVote(uint256,address)" 1 $YOUR_ADDRESS --rpc-url http://localhost:8545
```

**"Voting has ended"**
```bash
cast call $VOTING_ADDRESS "getQuestionDetails(uint256)" 1 --rpc-url http://localhost:8545
```

### Debug Commands

```bash
# Check MP token count
cast call $FACTORY_ADDRESS "getMPTokenCount()" --rpc-url http://localhost:8545

# Check token details
cast call $FACTORY_ADDRESS "getMPTokenData(uint256)" 1 --rpc-url http://localhost:8545

# Check if token expired
cast call $FACTORY_ADDRESS "isTokenExpired(uint256)" 1 --rpc-url http://localhost:8545

# Check current block timestamp
cast call "block.timestamp" --rpc-url http://localhost:8545

# Check question count
cast call $VOTING_ADDRESS "questionCount()" --rpc-url http://localhost:8545

# Check active questions
cast call $VOTING_ADDRESS "getActiveQuestions()" --rpc-url http://localhost:8545
```
