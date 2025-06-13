#!/bin/bash

ADMIN_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
ADMIN_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"


ACCOUNTS=(
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
    "0x90F79bf6EB2c4f870365E785982E1f101E93b906"
    "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"
    "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc"
    "0x976EA74026E726554dB657fA54763abd0C3a0aa9"
    "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955"
    "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f"
    "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720"
)


NAMES=(
    "John Smith"
    "Mary Johnson"
    "David Williams"
    "Sarah Brown"
    "James Wilson"
    "Emma Jones"
    "Michael Davies"
    "Elizabeth Taylor"
    "Robert Evans"
    "Jennifer Thomas"
    "Andrew Clark"
    "Patricia Lewis"
    "Richard Hall"
    "Susan White"
    "Charles Baker"
)

PARTIES=(
    "Conservative"
    "Labour"
    "Liberal Democrats"
    "Scottish National Party"
    "Green Party"
    "Plaid Cymru"
    "Democratic Unionist Party"
    "Sinn Féin"
    "Alliance Party"
    "Independent"
)

CONSTITUENCIES=(
    "Westminster North"
    "Islington South"
    "Birmingham Edgbaston"
    "Manchester Central"
    "Edinburgh South"
    "Cardiff West"
    "Belfast South"
    "Glasgow North"
    "Sheffield Central"
    "Norwich South"
    "Oxford East"
    "Bristol West"
    "Newcastle Central"
    "Liverpool Riverside"
    "Leeds Central"
)

RPC_URL="http://localhost:8545"
FACTORY_ADDRESS="" 


echo "Checking if Anvil is running..."
if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' $RPC_URL > /dev/null; then
    echo "Error: Anvil is not running. Please start Anvil first with 'anvil' and try again."
    exit 1
fi
echo "Anvil is running"


if [[ $1 == "--factory" && -n $2 ]]; then
    FACTORY_ADDRESS=$2
    echo "Using provided factory address: $FACTORY_ADDRESS"
else

    echo "No factory address provided. Deploying a new factory..."
    FACTORY_DEPLOY=$(forge create --rpc-url $RPC_URL --private-key $ADMIN_KEY --broadcast src/MPTokenFactory.sol:MPTokenFactory)
    

    FACTORY_ADDRESS=$(echo "$FACTORY_DEPLOY" | grep -o "Deployed to: 0x[0-9a-fA-F]\{40\}" | awk '{print $3}')
    
    if [[ -z $FACTORY_ADDRESS ]]; then

        FACTORY_ADDRESS=$(echo "$FACTORY_DEPLOY" | grep "Deployed to" | awk '{print $NF}')
    fi
    
    echo "MPTokenFactory deployed at: $FACTORY_ADDRESS"
fi

if [[ -z $FACTORY_ADDRESS ]]; then
    echo "Error: Could not determine factory address. Please provide one with --factory option."
    exit 1
fi


CURRENT_TIME=$(cast block latest --rpc-url $RPC_URL | grep timestamp | awk '{print $2}')
CURRENT_YEAR=2024
MAX_ACCOUNTS=${#ACCOUNTS[@]}
NUM_TO_CREATE=${3:-$MAX_ACCOUNTS} 


echo "Creating $NUM_TO_CREATE MP NFTs..."


if (( NUM_TO_CREATE > MAX_ACCOUNTS )); then
    echo "Warning: Requested more MPs than available accounts. Creating for ${MAX_ACCOUNTS} accounts only."
    NUM_TO_CREATE=$MAX_ACCOUNTS
fi

if (( NUM_TO_CREATE < 1 )); then
    NUM_TO_CREATE=1
fi

for (( i=1; i<=NUM_TO_CREATE; i++ )); do

    INDEX=$((i-1))
    RECIPIENT="${ACCOUNTS[$INDEX]}"
    

    NAME_INDEX=$((RANDOM % ${#NAMES[@]}))
    PARTY_INDEX=$((RANDOM % ${#PARTIES[@]}))
    CONSTITUENCY_INDEX=$((RANDOM % ${#CONSTITUENCIES[@]}))
    
    NAME="${NAMES[$NAME_INDEX]}"
    PARTY="${PARTIES[$PARTY_INDEX]}"
    CONSTITUENCY="${CONSTITUENCIES[$CONSTITUENCY_INDEX]}"
    

    YEARS_OFFSET=$((RANDOM % 4 + 1))
    EXPIRATION_OFFSET=$((YEARS_OFFSET * 365 * 24 * 60 * 60))
    EXPIRATION_TIME=$((CURRENT_TIME + EXPIRATION_OFFSET))
    
    echo "Creating MP Token for $NAME ($PARTY, $CONSTITUENCY)"
    echo "Recipient: $RECIPIENT"
    echo "Expiration: $(date -r $EXPIRATION_TIME)"

    CREATE_RESULT=$(cast send --rpc-url $RPC_URL --private-key $ADMIN_KEY $FACTORY_ADDRESS \
        "createMPToken(address,string,string,string,uint256,uint256)" \
        "$RECIPIENT" "$NAME" "$PARTY" "$CONSTITUENCY" "$CURRENT_YEAR" "$EXPIRATION_TIME" &>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        TX_HASH=$(echo "$CREATE_RESULT" | grep -o "0x[0-9a-f]\{64\}")
        echo "Created MP Token for $NAME (Transaction: ${TX_HASH:0:10}...)"
    else
        echo "Error creating MP Token for $NAME: $CREATE_RESULT"
        echo "Skipping to next token..."
        continue
    fi

    sleep 0.5
done

MP_COUNT=$(cast call --rpc-url $RPC_URL $FACTORY_ADDRESS "getMPTokenCount()(uint256)")
echo "Done! Created MP NFTs. Total MP count: $MP_COUNT"

echo "FACTORY_ADDRESS=$FACTORY_ADDRESS" > .mp_env
echo "Factory address saved to .mp_env file for use with other scripts."

exit 0