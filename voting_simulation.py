#!/bin/python
import os
import time

print("=== MP VOTING SYSTEM WITH 100 ETH STAKING DEMONSTRATION ===")

os.environ["PRIVATE_KEY"] = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
ADMIN_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
ADMIN_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

print("=== DEPLOYING CONTRACTS ===")
FACTORY='forge script script/Deploy.sol:DeployMPTokenFactory --rpc-url http://localhost:8545 --private-key {} --broadcast 2>/dev/null | grep "MPTokenFactory deployed at:" | cut -d" " -f6'.format(ADMIN_KEY)
FACTORY = os.popen(FACTORY).read().replace("\n","")
os.environ["MP_FACTORY_ADDRESS"] = "{}".format(FACTORY)

MP="./create_mp_nfts.sh --factory {} ".format(FACTORY)
_ = os.popen(MP).read()

VOTING_ADDRESS='forge script script/DeployMPVoting.sol:DeployMPVoting --rpc-url http://localhost:8545 --broadcast 2>/dev/null | grep "MPVoting deployed at:" | cut -d" " -f6'
VOTING_ADDRESS = os.popen(VOTING_ADDRESS).read().replace("\n","")

print("Factory Address:", FACTORY)
print("MP NFT Creation:", _)
print("Voting Address:", VOTING_ADDRESS)

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

question1 = 'cast send --rpc-url http://localhost:8545 --private-key {} {} "createQuestion(string,uint256,uint256)" "Czy nowa ustawa o ochronie środowiska powinna zostać uchwalona?" {} {}'.format(ADMIN_KEY, VOTING_ADDRESS, int(time.time()+60), int(time.time()+500))
question2 = 'cast send --rpc-url http://localhost:8545 --private-key {} {} "createQuestion(string,uint256,uint256)" "Czy popierasz proponowaną reformę edukacji?" {} {}'.format(ADMIN_KEY, VOTING_ADDRESS, int(time.time()+60), int(time.time()+500))
question3 = 'cast send --rpc-url http://localhost:8545 --private-key {} {} "createQuestion(string,uint256,uint256)" "Czy rząd powinien zwiększyć finansowanie odnawialnych źródeł energii?" {} {}'.format(ADMIN_KEY, VOTING_ADDRESS, int(time.time()+60), int(time.time()+500))

print("Question 1:", question1)
print("Question 2:", question2)
print("Question 3:", question3)

_ = os.popen(question1).read()
_ = os.popen(question2).read()
_ = os.popen(question3).read()

print("Questions created!")

print("\n=== INITIAL BALANCES (Before Any Voting) ===")
initial_balances = {}
for private_key, address, label in voters:
    initial_balances[address] = check_balance(address, label)
admin_initial = check_balance(ADMIN_ADDRESS, "Admin (Vault)")

print("\nWaiting for voting to start (1 minute)...")
time.sleep(65)

print("\n=== VOTING WITH 100 ETH STAKES ===")
print("Each MP must stake 100 ETH to vote!")
print("Question 1 pattern: 3xYES (winners), 2xNO (losers), 1xABSTAIN (loser)")

v1='cast send --rpc-url http://localhost:8545/ --private-key "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" {} "vote(uint256,uint256)" "1" "0" --value 100ether'.format(VOTING_ADDRESS)
v2='cast send --rpc-url http://localhost:8545/ --private-key "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6" {} "vote(uint256,uint256)" "1" "0" --value 100ether'.format(VOTING_ADDRESS)
v3='cast send --rpc-url http://localhost:8545/ --private-key "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a" {} "vote(uint256,uint256)" "1" "0" --value 100ether'.format(VOTING_ADDRESS)
v4='cast send --rpc-url http://localhost:8545/ --private-key "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba" {} "vote(uint256,uint256)" "1" "1" --value 100ether'.format(VOTING_ADDRESS)
v5='cast send --rpc-url http://localhost:8545/ --private-key "0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e" {} "vote(uint256,uint256)" "1" "1" --value 100ether'.format(VOTING_ADDRESS)
v6='cast send --rpc-url http://localhost:8545/ --private-key "0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356" {} "vote(uint256,uint256)" "1" "2" --value 100ether'.format(VOTING_ADDRESS)

print("MP-2 voting YES with 100 ETH stake...")
_ = os.popen(v1).read()
print("MP-3 voting YES with 100 ETH stake...")
_ = os.popen(v2).read()
print("MP-4 voting YES with 100 ETH stake...")
_ = os.popen(v3).read()
print("MP-5 voting NO with 100 ETH stake...")
_ = os.popen(v4).read()
print("MP-6 voting NO with 100 ETH stake...")
_ = os.popen(v5).read()
print("MP-7 voting ABSTAIN with 100 ETH stake...")
_ = os.popen(v6).read()

print("\n=== BALANCES AFTER VOTING (Each MP Lost 100 ETH) ===")
for private_key, address, label in voters:
    check_balance(address, label + " (after voting)")

print("Total staked: 600 ETH (6 MPs × 100 ETH)")

print("\n=== QUESTION 2: Education Reform (100 ETH stakes) ===")
print("Pattern: 2xYES (losers), 3xNO (winners), 1xABSTAIN (loser)")

v1='cast send --rpc-url http://localhost:8545/ --private-key "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" {} "vote(uint256,uint256)" "2" "0" --value 100ether'.format(VOTING_ADDRESS)
v2='cast send --rpc-url http://localhost:8545/ --private-key "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6" {} "vote(uint256,uint256)" "2" "0" --value 100ether'.format(VOTING_ADDRESS)
v3='cast send --rpc-url http://localhost:8545/ --private-key "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a" {} "vote(uint256,uint256)" "2" "1" --value 100ether'.format(VOTING_ADDRESS)
v4='cast send --rpc-url http://localhost:8545/ --private-key "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba" {} "vote(uint256,uint256)" "2" "1" --value 100ether'.format(VOTING_ADDRESS)
v5='cast send --rpc-url http://localhost:8545/ --private-key "0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e" {} "vote(uint256,uint256)" "2" "1" --value 100ether'.format(VOTING_ADDRESS)
v6='cast send --rpc-url http://localhost:8545/ --private-key "0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356" {} "vote(uint256,uint256)" "2" "2" --value 100ether'.format(VOTING_ADDRESS)

_ = os.popen(v1).read()
_ = os.popen(v2).read()
_ = os.popen(v3).read()
_ = os.popen(v4).read()
_ = os.popen(v5).read()
_ = os.popen(v6).read()

print("=== QUESTION 3: Renewable Energy (100 ETH stakes) ===")
print("Pattern: 1xYES (loser), 1xNO (loser), 4xABSTAIN (winners)")

v1='cast send --rpc-url http://localhost:8545/ --private-key "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" {} "vote(uint256,uint256)" "3" "2" --value 100ether'.format(VOTING_ADDRESS)
v2='cast send --rpc-url http://localhost:8545/ --private-key "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6" {} "vote(uint256,uint256)" "3" "2" --value 100ether'.format(VOTING_ADDRESS)
v3='cast send --rpc-url http://localhost:8545/ --private-key "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a" {} "vote(uint256,uint256)" "3" "2" --value 100ether'.format(VOTING_ADDRESS)
v4='cast send --rpc-url http://localhost:8545/ --private-key "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba" {} "vote(uint256,uint256)" "3" "2" --value 100ether'.format(VOTING_ADDRESS)
v5='cast send --rpc-url http://localhost:8545/ --private-key "0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e" {} "vote(uint256,uint256)" "3" "0" --value 100ether'.format(VOTING_ADDRESS)
v6='cast send --rpc-url http://localhost:8545/ --private-key "0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356" {} "vote(uint256,uint256)" "3" "1" --value 100ether'.format(VOTING_ADDRESS)

_ = os.popen(v1).read()
_ = os.popen(v2).read()
_ = os.popen(v3).read()
_ = os.popen(v4).read()
_ = os.popen(v5).read()
_ = os.popen(v6).read()

print("\n=== TOTAL STAKES: 1800 ETH (18 votes × 100 ETH) ===")

yes_c='cast call '+ VOTING_ADDRESS + ' "getYesVotesCount(uint256)" {} --rpc-url http://localhost:8545/'
no_c='cast call '+ VOTING_ADDRESS + ' "getNoVotesCount(uint256)" {} --rpc-url http://localhost:8545/'

print("\n=== VOTE COUNTS ===")
print("============Question1============")
y=os.popen(yes_c.format(1)).read()
n=os.popen(no_c.format(1)).read()
print("Yes count {}".format(y.strip()))
print("No count {}".format(n.strip()))
print("============Question2============")
y=os.popen(yes_c.format(2)).read()
n=os.popen(no_c.format(2)).read()
print("Yes count {}".format(y.strip()))
print("No count {}".format(n.strip()))
print("============Question3============")
y=os.popen(yes_c.format(3)).read()
n=os.popen(no_c.format(3)).read()
print("Yes count {}".format(y.strip()))
print("No count {}".format(n.strip()))

print("\n=== FAST FORWARDING TIME TO END VOTING ===")
time.sleep(200)
_ = os.popen('cast rpc anvil_mine --rpc-url http://localhost:8545').read()

print("Fast forwarding blockchain time by 1 hour...")
_ = os.popen('cast rpc evm_increaseTime 3600 --rpc-url http://localhost:8545').read()
_ = os.popen('cast rpc anvil_mine --rpc-url http://localhost:8545').read()

print("Time fast-forwarded successfully")

print("\n=== CLOSING VOTING ===")
close1 = os.popen('cast send --rpc-url http://localhost:8545 --private-key {} {} "closeQuestion(uint256)" 1'.format(ADMIN_KEY, VOTING_ADDRESS)).read()
close2 = os.popen('cast send --rpc-url http://localhost:8545 --private-key {} {} "closeQuestion(uint256)" 2'.format(ADMIN_KEY, VOTING_ADDRESS)).read()
close3 = os.popen('cast send --rpc-url http://localhost:8545 --private-key {} {} "closeQuestion(uint256)" 3'.format(ADMIN_KEY, VOTING_ADDRESS)).read()

print("All questions closed successfully")

print("\n=== VOTING RESULTS ===")
r1 = os.popen('cast call {} "getVotingResults(uint256)" 1 --rpc-url http://localhost:8545/'.format(VOTING_ADDRESS)).read()
r2 = os.popen('cast call {} "getVotingResults(uint256)" 2 --rpc-url http://localhost:8545/'.format(VOTING_ADDRESS)).read()
r3 = os.popen('cast call {} "getVotingResults(uint256)" 3 --rpc-url http://localhost:8545/'.format(VOTING_ADDRESS)).read()

print("Question 1 (Environmental): YES won = {}".format(r1.strip()))
print("Question 2 (Education): YES won = {}".format(r2.strip()))  
print("Question 3 (Renewable): YES won = {}".format(r3.strip()))

print("\n=== DETAILED VOTE CHECK FOR ALL QUESTIONS ===")

vote_options = {0: "YES", 1: "NO", 2: "ABSTAIN"}

for question_id in range(1, 4):
    print(f"\n============Question {question_id}============")
    
    for private_key, address, label in voters:
        vote_result = os.popen('cast call {} "checkVote(uint256, address)" {} "{}" --rpc-url http://localhost:8545/'.format(VOTING_ADDRESS, question_id, address)).read().replace("\n","")
        
        if len(vote_result) >= 66:
            has_voted = int(vote_result[2:66], 16)
            vote_choice = int(vote_result[66:], 16)
            
            if has_voted:
                vote_name = vote_options.get(vote_choice, "UNKNOWN")
                print(f"{label} ({address}): Voted {vote_name}")
            else:
                print(f"{label} ({address}): Did not vote")
        else:
            print(f"{label} ({address}): Error reading vote")

print("\n=== STAKE CLAIMING DEMONSTRATION (WHERE THE MONEY FLOWS!) ===")

print("\n============Question 1: Environmental Bill============")
print("Result: YES won (3 votes) - NO and ABSTAIN lost")
print("Winners (YES voters): Get 100 ETH back each")
print("Losers (NO/ABSTAIN): Get 50 ETH back each, vault gets 50 ETH each")

vote_patterns_q1 = [
    (0, "YES", "WINNER"),
    (0, "YES", "WINNER"),  
    (0, "YES", "WINNER"),
    (1, "NO", "LOSER"),
    (1, "NO", "LOSER"),
    (2, "ABSTAIN", "LOSER")
]

print("\n=== CLAIMING STAKES FROM QUESTION 1 ===")
for i, (private_key, address, label) in enumerate(voters):
    vote_option, vote_name, result = vote_patterns_q1[i]
    
    print(f"\n{label} ({vote_name} voter - {result}) claiming stake from Q1:")
    
    balance_before_wei = os.popen(f'cast balance {address} --rpc-url http://localhost:8545').read().strip()
    balance_before = int(balance_before_wei) / 1e18
    print(f"  Before claim: {balance_before:.4f} ETH")
    
    admin_before_wei = os.popen(f'cast balance {ADMIN_ADDRESS} --rpc-url http://localhost:8545').read().strip()
    admin_before = int(admin_before_wei) / 1e18
    
    claim_cmd = f'cast send --rpc-url http://localhost:8545/ --private-key "{private_key}" {VOTING_ADDRESS} "claimStake(uint256)" "1"'
    claim_result = os.popen(claim_cmd).read()
    
    balance_after_wei = os.popen(f'cast balance {address} --rpc-url http://localhost:8545').read().strip()
    balance_after = int(balance_after_wei) / 1e18
    print(f"  After claim: {balance_after:.4f} ETH")
    
    admin_after_wei = os.popen(f'cast balance {ADMIN_ADDRESS} --rpc-url http://localhost:8545').read().strip()
    admin_after = int(admin_after_wei) / 1e18
    
    mp_change = balance_after - balance_before
    admin_change = admin_after - admin_before
    total_change = balance_after - (initial_balances[address] / 1e18)
    
    print(f"  MP received: {mp_change:.1f} ETH")
    if admin_change > 0:
        print(f"  Vault earned: {admin_change:.1f} ETH")
    print(f"  Total net change: {total_change:.1f} ETH")
    
    if result == "WINNER":
        print("  WINNER: Should get ~100 ETH back (full stake)")
    else:
        print("  LOSER: Should get ~50 ETH back (half stake)")

print("\n=== ERROR CASE TESTING ===")
print("Testing insufficient stake (should fail)...")

print("Trying to vote with 1 ETH instead of 100 ETH on question 2...")
error_cmd = f'cast send --rpc-url http://localhost:8545/ --private-key "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" {VOTING_ADDRESS} "vote(uint256,uint256)" "2" "0" --value 1ether 2>&1'
error_result = os.popen(error_cmd).read()
if "revert" in error_result.lower() or "error" in error_result.lower() or "must stake exactly" in error_result:
    print("Correctly failed: Cannot vote with 1 ETH instead of 100 ETH")
else:
    print("Unexpected: Vote should have failed")
    print("Error output:", error_result[:100])

print("\n=== FINAL FINANCIAL SUMMARY ===")

admin_final_wei = os.popen(f'cast balance {ADMIN_ADDRESS} --rpc-url http://localhost:8545').read().strip()
admin_final = int(admin_final_wei) / 1e18
total_vault_earnings = admin_final - (admin_initial / 1e18)
print(f"Admin (Vault) final balance: {admin_final:.4f} ETH")
print(f"Total vault earnings: {total_vault_earnings:.1f} ETH")
