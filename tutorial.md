# MP Voting System Tutorial - Corrected Version

## 1: Environment Setup
```bash
anvil

export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb378cbed5efcae784d7bf4f2ff80"

export RPC_URL="http://localhost:8545"

```

## 2: Deploy Contracts
```bash
forge script script/Deploy.sol:DeployMPTokenFactory --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

export FACTORY_ADDRESS="0x5FbDB2315678afecb367f032d93F642f64180aa3"

export MP_FACTORY_ADDRESS=$FACTORY_ADDRESS
forge script script/DeployMPVoting.sol:DeployMPVoting --rpc-url $RPC_URL --broadcast

export VOTING_ADDRESS="0xc6e7DF5E7b4f2A278906862b61205850344D4e7d"
```

## 3: Create MP NFTs
```bash
bash ./create_mp_nfts.sh

cast call $FACTORY_ADDRESS "getMPTokenCount()" --rpc-url $RPC_URL
```

## 4: Check Account Balances
```bash
# Check balances for test accounts (each should have ~10000 ETH on Anvil)
cast balance 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --rpc-url $RPC_URL --ether
cast balance 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC --rpc-url $RPC_URL --ether
cast balance 0x90F79bf6EB2c4f870365E785982E1f101E93b906 --rpc-url $RPC_URL --ether
```

## 5: Create Voting Questions with Staking
```bash
# Calculate start/end times (start in 2 min, end in 10 min)
START_TIME=$(($(date +%s) + 120))
END_TIME=$(($(date +%s) + 600))

cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $VOTING_ADDRESS \
  "createQuestion(string,uint256,uint256)" \
  "Should we implement a 7-day working week?" \
  $START_TIME $END_TIME

cast call $VOTING_ADDRESS "questionCount()" --rpc-url $RPC_URL
# Should return 1
```

## 6: Wait for Voting to Start
```bash
echo "Waiting for voting to start..."
sleep 120
echo "Voting period is now active!"
```

## 7: MPs Vote with 100 ETH Stakes
CRITICAL: Each vote requires exactly 100 ETH stake!

```bash
# MP Account 1 
export MP1_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
cast send --rpc-url $RPC_URL --private-key $MP1_KEY $VOTING_ADDRESS \
  "vote(uint256,uint256)" "1" "0" --value 100ether

# MP Account 2 
export MP2_KEY="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
cast send --rpc-url $RPC_URL --private-key $MP2_KEY $VOTING_ADDRESS \
  "vote(uint256,uint256)" "1" "1" --value 100ether

# MP Account 3 
export MP3_KEY="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
cast send --rpc-url $RPC_URL --private-key $MP3_KEY $VOTING_ADDRESS \
  "vote(uint256,uint256)" "1" "2" --value 100ether
```

## 8: Monitor Voting Progress
```bash
# Check YES votes
cast call $VOTING_ADDRESS "getYesVotesCount(uint256)" "1" --rpc-url $RPC_URL

# Check NO votes  
cast call $VOTING_ADDRESS "getNoVotesCount(uint256)" "1" --rpc-url $RPC_URL

# Check all vote counts
cast call $VOTING_ADDRESS "getAllVoteCounts(uint256)" "1" --rpc-url $RPC_URL

# Check total staked amount
cast call $VOTING_ADDRESS "getQuestionDetails(uint256)" "1" --rpc-url $RPC_URL

# Check specific voter's stake
cast call $VOTING_ADDRESS "getStakeInfo(uint256,address)" "1" "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" --rpc-url $RPC_URL
```

## 9: Wait and Close Voting
```bash
# Close the question (admin only)
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $VOTING_ADDRESS \
  "closeQuestion(uint256)" "1"
```

## 10: Check Results
```bash
# Get voting results (true = YES won, false = NO won or draw)
cast call $VOTING_ADDRESS "getVotingResults(uint256)" "1" --rpc-url $RPC_URL

# Get detailed results
cast call $VOTING_ADDRESS "getDetailedVotingResults(uint256)" "1" --rpc-url $RPC_URL

# Check how specific address voted
cast call $VOTING_ADDRESS "checkVote(uint256,address)" "1" "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" --rpc-url $RPC_URL
```

## 11: Claim Stakes
Staking Rules:
- Winners get 100% of their stake back
- Losers get 50% back
- Remaining 50% from losers goes to vault (question creator)

```bash
cast send --rpc-url $RPC_URL --private-key $MP1_KEY $VOTING_ADDRESS "claimStake(uint256)" "1"
cast send --rpc-url $RPC_URL --private-key $MP2_KEY $VOTING_ADDRESS "claimStake(uint256)" "1"  
cast send --rpc-url $RPC_URL --private-key $MP3_KEY $VOTING_ADDRESS "claimStake(uint256)" "1"
```

## 12: Error Demonstrations
```bash
# Try voting without MP NFT (should fail)
export NON_MP_KEY="0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97"
cast send --rpc-url $RPC_URL --private-key $NON_MP_KEY $VOTING_ADDRESS \
  "vote(uint256,uint256)" "1" "0" --value 100ether

# Try voting with wrong stake amount (should fail)
cast send --rpc-url $RPC_URL --private-key $MP1_KEY $VOTING_ADDRESS \
  "vote(uint256,uint256)" "1" "0" --value 50ether

# Try double voting (should fail)
cast send --rpc-url $RPC_URL --private-key $MP1_KEY $VOTING_ADDRESS \
  "vote(uint256,uint256)" "1" "0" --value 100ether
```

## 13: Admin Functions
```bash
# Add new admin
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $VOTING_ADDRESS \
  "addAdmin(address)" "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

# Check if address is admin
cast call $VOTING_ADDRESS "isAdmin(address)" "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" --rpc-url $RPC_URL

# Check if address is valid MP voter
cast call $VOTING_ADDRESS "isValidMPVoter(address)" "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" --rpc-url $RPC_URL
```

## 14: Final Balance Summary
```bash
cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url $RPC_URL --ether  # Admin/Vault
cast balance 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --rpc-url $RPC_URL --ether  # MP1
cast balance 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC --rpc-url $RPC_URL --ether  # MP2
cast balance 0x90F79bf6EB2c4f870365E785982E1f101E93b906 --rpc-url $RPC_URL --ether  # MP3
```
