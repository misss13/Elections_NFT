# MP NFT Voting System

Blockchain-based voting system for Members of Parliament using NFT identity verification and ETH staking mechanisms.


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
forge build
```

## Quick Start

### Terminal 1: Start blockchain
```bash
anvil
```

### Terminal 2: Deploy contracts
```bash
export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
export RPC_URL="http://localhost:8545"

# Deploy MP Token Factory
forge script script/Deploy.sol:DeployMPTokenFactory \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast

# Set factory address from deployment output
export FACTORY_ADDRESS="0x5FbDB2315678afecb367f032d93F642f64180aa3"

# Deploy Voting Contract
forge script script/DeployMPVoting.sol:DeployMPVoting \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast

# Set voting address from deployment output
export VOTING_ADDRESS="0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"

# Create MP NFTs for test accounts
forge script script/CreateMPTokensForAnvil.sol:CreateMPTokensForAnvil \
  --rpc-url $RPC_URL \
  --broadcast
```

## Demo Options

### Option 1: Python Script (Automated)
Run complete voting simulation:
```bash
python3 voting_simulation.py
```

### Option 2: Manual Step-by-Step
**See `tutorial.md` for complete step-by-step instructions**

Key commands from tutorial:

```bash
START_TIME=$(($(date +%s) + 120))
END_TIME=$(($(date +%s) + 600))
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $VOTING_ADDRESS \
  "createQuestion(string,uint256,uint256)" \
  "Should we implement a 7-day working week?" \
  $START_TIME $END_TIME

export MP1_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
cast send --rpc-url $RPC_URL --private-key $MP1_KEY $VOTING_ADDRESS \
  "vote(uint256,uint256)" "1" "0" --value 100ether

cast call $VOTING_ADDRESS "getAllVoteCounts(uint256)" "1" --rpc-url $RPC_URL

cast send --rpc-url $RPC_URL --private-key $MP1_KEY $VOTING_ADDRESS "claimStake(uint256)" "1"
```

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
RPC_URL=http://localhost:8545
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

tutorial.md               # Step-by-step tutorial
voting_simulation.py      # Automated demo simulation
create_mp_nfts.sh         # Generate MP NFT tokens
```


## Monitoring Commands

```bash
cast call $FACTORY_ADDRESS "getMPTokenCount()" --rpc-url $RPC_URL

cast call $VOTING_ADDRESS "isValidMPVoter(address)" $ADDRESS --rpc-url $RPC_URL

cast call $VOTING_ADDRESS "questionCount()" --rpc-url $RPC_URL

cast call $VOTING_ADDRESS "getActiveQuestions()" --rpc-url $RPC_URL

cast call $VOTING_ADDRESS "getYesVotesCount(uint256)" "1" --rpc-url $RPC_URL
cast call $VOTING_ADDRESS "getNoVotesCount(uint256)" "1" --rpc-url $RPC_URL

cast call $VOTING_ADDRESS "getStakeInfo(uint256,address)" "1" $ADDRESS --rpc-url $RPC_URL

cast call $VOTING_ADDRESS "getVotingResults(uint256)" "1" --rpc-url $RPC_URL
```

## Troubleshooting

### Common Errors and Solutions

**"Not a valid MP voter"**
```bash
cast call $VOTING_ADDRESS "isValidMPVoter(address)" $YOUR_ADDRESS --rpc-url $RPC_URL
cast call $FACTORY_ADDRESS "getMPTokenData(uint256)" 1 --rpc-url $RPC_URL
```

**"Must stake exactly 100 ETH"**
```bash
cast send $VOTING_ADDRESS "vote(uint256,uint256)" 1 0 --value 100ether --private-key $KEY --rpc-url $RPC_URL
```

**"Voting has not started yet" / "Voting has ended"**
```bash
cast call $VOTING_ADDRESS "getQuestionDetails(uint256)" 1 --rpc-url $RPC_URL
cast call "block.timestamp" --rpc-url $RPC_URL
```

**"Already voted"**
```bash
cast call $VOTING_ADDRESS "checkVote(uint256,address)" 1 $YOUR_ADDRESS --rpc-url $RPC_URL
```

### Debug Commands

```bash
cast call "block.timestamp" --rpc-url $RPC_URL

cast call $FACTORY_ADDRESS "getMPTokenData(uint256)" 1 --rpc-url $RPC_URL

cast call $FACTORY_ADDRESS "isTokenExpired(uint256)" 1 --rpc-url $RPC_URL

cast call $VOTING_ADDRESS "getQuestionDetails(uint256)" 1 --rpc-url $RPC_URL

cast balance $ADDRESS --rpc-url $RPC_URL --ether
```

## Documentation

- **`tutorial.md`** - Complete step-by-step tutorial with examples
- **`src/`** - Smart contract documentation in code comments
- **`test/`** - Test cases with usage examples

`tutorial.md` provides detailed explanations and real examples of each feature.
