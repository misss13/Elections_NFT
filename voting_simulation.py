#!/bin/python
import os
import time

print("=== MP VOTING SYSTEM WITH 100 ETH STAKING + DRAW DEMONSTRATION ===")

os.environ["PRIVATE_KEY"] = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
ADMIN_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
ADMIN_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

print("=== DEPLOYING CONTRACTS ===")


print("Deploying MPTokenFactory...")
factory_cmd = f'forge script script/Deploy.sol:DeployMPTokenFactory --rpc-url http://localhost:8545 --private-key {ADMIN_KEY} --broadcast 2>/dev/null'
factory_output = os.popen(factory_cmd).read()
#print("Factory deployment output:")
#print(factory_output)

FACTORY = ""
for line in factory_output.split('\n'):
    if "MPTokenFactory deployed at:" in line:
        FACTORY = line.split(":")[-1].strip()
        break

if not FACTORY:
    print("ERROR: Failed to deploy MPTokenFactory")
    print("Full output:", factory_output)
    exit(1)

os.environ["FACTORY_ADDRESS"] = FACTORY
print(f"Factory Address: {FACTORY}")

print("=== Creating MP NFTs ===")
mp_cmd = f"./create_mp_nfts.sh --factory {FACTORY} 2>/dev/null"
mp_output = os.popen(mp_cmd).read()
print("MP NFT Creation output:")
print(mp_output)
print("Deploying MPVoting...")
voting_cmd = f'forge script script/DeployMPVoting.sol:DeployMPVoting --rpc-url http://localhost:8545 --private-key {ADMIN_KEY} --broadcast 2>/dev/null'
voting_output = os.popen(voting_cmd).read()
#print("Voting deployment output:")
#print(voting_output)

VOTING_ADDRESS = ""
for line in voting_output.split('\n'):
    if "MPVoting deployed at:" in line:
        VOTING_ADDRESS = line.split(":")[-1].strip()
        break

if not VOTING_ADDRESS:
    print("ERROR: Failed to deploy MPVoting contract")
    print("Full output:", voting_output)
    exit(1)

print(f"Voting Address: {VOTING_ADDRESS}")
def check_balance(address, label):
    balance_wei = os.popen(f'cast balance {address} --rpc-url http://localhost:8545').read().strip()
    balance_eth = int(balance_wei) / 1e18
    print(f"{label}: {balance_eth:.4f} ETH")
    return int(balance_wei)

voters = [
    ("0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a", "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", "MP-2"),
    ("0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6", "0x90F79bf6EB2c4f870365E785982E1f101E93b906", "MP-3"),
    ("0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a", "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65", "MP-4"),
    ("0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba", "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc", "MP-5"),
    ("0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e", "0x976EA74026E726554dB657fA54763abd0C3a0aa9", "MP-6"),
    ("0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356", "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955", "MP-7")
]

print("\n=== CREATING VOTING QUESTIONS ===")

start_time = int(time.time()) + 60
end_time = int(time.time()) + 500

questions = [
    "Environmental protection bill?",
    "Education reform proposal?",
    "Renewable energy funding?",
    "Summer break proposal?"
]

for i, question in enumerate(questions, 1):
    print(f"Creating question {i}: {question}", end=" ")
    cmd = f'cast send --rpc-url http://localhost:8545 --private-key {ADMIN_KEY} {VOTING_ADDRESS} "createQuestion(string,uint256,uint256)" "{question}" {start_time} {end_time}'
    result = os.popen(cmd).read()
    if "Transaction hash" in result or "blockHash" in result:
        print(f"( Question {i} created successfully )")
    else:
        print(f"( Question {i} creation failed: )")
        print(result)
print("\n=== INITIAL BALANCES ===")
initial_balances = {}
for private_key, address, label in voters:
    initial_balances[address] = check_balance(address, label)
admin_initial = check_balance(ADMIN_ADDRESS, "Admin")

print(f"\nWaiting for voting to start (65 seconds)...")
time.sleep(65)

voting_patterns = [
    # Question 1: 3 YES, 2 NO, 1 ABSTAIN
    [0, 0, 0, 1, 1, 2],
    # Question 2: 2 YES, 3 NO, 1 ABSTAIN  
    [0, 0, 1, 1, 1, 2],
    # Question 3: 1 YES, 1 NO, 4 ABSTAIN
    [2, 2, 2, 2, 0, 1],
    # Question 4: 2 YES, 2 NO, 2 ABSTAIN (DRAW)
    [0, 0, 1, 1, 2, 2]
]

for q in range(4):
    print(f"\n=== VOTING QUESTION {q+1} ===")
    for i, (private_key, address, label) in enumerate(voters):
        vote_option = voting_patterns[q][i]
        vote_names = ["YES", "NO", "ABSTAIN"]
        print(f"{label} voting {vote_names[vote_option]}...")
        
        cmd = f'cast send --rpc-url http://localhost:8545 --private-key "{private_key}" {VOTING_ADDRESS} "vote(uint256,uint256)" "{q+1}" "{vote_option}" --value 100ether'
        result = os.popen(cmd).read()
        if "Transaction hash" not in result and "blockHash" not in result:
            print(f"Vote failed for {label}: {result}")

print("\n=== VOTE COUNTS ===")
for q in range(1, 5):
    print(f"Question {q}:")
    yes_cmd = f'cast call {VOTING_ADDRESS} "getYesVotesCount(uint256)" {q} --rpc-url http://localhost:8545'
    no_cmd = f'cast call {VOTING_ADDRESS} "getNoVotesCount(uint256)" {q} --rpc-url http://localhost:8545'
    
    y = os.popen(yes_cmd).read().strip()
    n = os.popen(no_cmd).read().strip()
    
    try:
        yes_count = int(y, 16) if y.startswith('0x') else int(y)
        no_count = int(n, 16) if n.startswith('0x') else int(n)
        print(f"  Yes: {yes_count}")
        print(f"  No: {no_count}")
    except:
        print(f"  Yes: {y}")
        print(f"  No: {n}")

print("\nFast forwarding time...")
time.sleep(100)
_ = os.popen('cast rpc anvil_mine --rpc-url http://localhost:8545').read()
_ = os.popen('cast rpc evm_increaseTime 3600 --rpc-url http://localhost:8545').read()
_ = os.popen('cast rpc anvil_mine --rpc-url http://localhost:8545').read()

print("\n=== CLOSING VOTING ===")
for q in range(1, 5):
    print(f"Closing question {q}...")
    cmd = f'cast send --rpc-url http://localhost:8545 --private-key {ADMIN_KEY} {VOTING_ADDRESS} "closeQuestion(uint256)" {q}'
    result = os.popen(cmd).read()
    if "Transaction hash" not in result and "blockHash" not in result:
        print(f"Failed to close question {q}: {result}")

print("\n=== VOTING RESULTS ===")
for q in range(1, 5):
    cmd = f'cast call {VOTING_ADDRESS} "getVotingResults(uint256)" {q} --rpc-url http://localhost:8545'
    result = os.popen(cmd).read().strip()
    yes_won = result == "true" or result == "0x0000000000000000000000000000000000000000000000000000000000000001"
    print(f"Question {q} YES won: {yes_won}")

print("\n=== DRAW DETECTION ===")
draw_cmd = f'cast call {VOTING_ADDRESS} "isQuestionDraw(uint256)" 4 --rpc-url http://localhost:8545'
draw_result = os.popen(draw_cmd).read().strip()
is_draw = draw_result == "true" or draw_result == "0x0000000000000000000000000000000000000000000000000000000000000001"
print(f"Question 4 is draw: {is_draw}")

if is_draw:
    tied_cmd = f'cast call {VOTING_ADDRESS} "getTiedOptions(uint256)" 4 --rpc-url http://localhost:8545'
    tied_result = os.popen(tied_cmd).read().strip()
    print(f"Tied options: {tied_result}")

print("\n=== STAKE CLAIMING QUESTION 1 ===")
vote_patterns_q1 = [
    (0, "YES", "WINNER"),
    (0, "YES", "WINNER"),  
    (0, "YES", "WINNER"),
    (1, "NO", "LOSER"),
    (1, "NO", "LOSER"),
    (2, "ABSTAIN", "LOSER")
]

for i, (private_key, address, label) in enumerate(voters):
    vote_option, vote_name, result = vote_patterns_q1[i]
    
    balance_before_wei = os.popen(f'cast balance {address} --rpc-url http://localhost:8545').read().strip()
    balance_before = int(balance_before_wei) / 1e18
    
    claim_cmd = f'cast send --rpc-url http://localhost:8545 --private-key "{private_key}" {VOTING_ADDRESS} "claimStake(uint256)" "1"'
    claim_result = os.popen(claim_cmd).read()
    
    balance_after_wei = os.popen(f'cast balance {address} --rpc-url http://localhost:8545').read().strip()
    balance_after = int(balance_after_wei) / 1e18
    
    mp_change = balance_after - balance_before
    print(f"{label} ({vote_name}) received: {mp_change:.1f} ETH")

print("\n=== STAKE CLAIMING QUESTION 4 DRAW ===")
vault_balance_before_draw_wei = os.popen(f'cast balance {ADMIN_ADDRESS} --rpc-url http://localhost:8545').read().strip()
vault_balance_before_draw = int(vault_balance_before_draw_wei) / 1e18

vote_patterns_q4 = [
    (0, "YES"),
    (0, "YES"),  
    (1, "NO"),
    (1, "NO"),
    (2, "ABSTAIN"),
    (2, "ABSTAIN")
]

for i, (private_key, address, label) in enumerate(voters):
    vote_option, vote_name = vote_patterns_q4[i]
    
    balance_before_wei = os.popen(f'cast balance {address} --rpc-url http://localhost:8545').read().strip()
    balance_before = int(balance_before_wei) / 1e18
    
    claim_cmd = f'cast send --rpc-url http://localhost:8545 --private-key "{private_key}" {VOTING_ADDRESS} "claimStake(uint256)" "4"'
    claim_result = os.popen(claim_cmd).read()
    
    balance_after_wei = os.popen(f'cast balance {address} --rpc-url http://localhost:8545').read().strip()
    balance_after = int(balance_after_wei) / 1e18
    
    mp_change = balance_after - balance_before
    print(f"{label} ({vote_name}) received: {mp_change:.1f} ETH")

vault_balance_after_draw_wei = os.popen(f'cast balance {ADMIN_ADDRESS} --rpc-url http://localhost:8545').read().strip()
vault_balance_after_draw = int(vault_balance_after_draw_wei) / 1e18
vault_earnings_from_draw = vault_balance_after_draw - vault_balance_before_draw

print(f"\nVault earnings from draw: {vault_earnings_from_draw:.4f} ETH")

print("\n=== FINAL BALANCES ===")
admin_final_wei = os.popen(f'cast balance {ADMIN_ADDRESS} --rpc-url http://localhost:8545').read().strip()
admin_final = int(admin_final_wei) / 1e18
total_vault_earnings = admin_final - (admin_initial / 1e18)
print(f"Admin final balance: {admin_final:.4f} ETH")
print(f"Total vault earnings: {total_vault_earnings:.1f} ETH")
