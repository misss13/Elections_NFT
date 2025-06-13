// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/MPTokenFactory.sol";
import "../src/MPVoting.sol";

contract CreateMPTokensForAnvil is Script {

    address[10] public anvilAccounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, // Admin (0)
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8, // (1)
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, // (2)
        0x90F79bf6EB2c4f870365E785982E1f101E93b906, // (3)
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65, // (4)
        0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc, // (5)
        0x976EA74026E726554dB657fA54763abd0C3a0aa9, // (6)
        0x14dC79964da2C08b23698B3D3cc7Ca32193d9955, // (7)
        0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f, // (8)
        0xa0Ee7A142d267C1f36714E4a8F75612F20a79720  // (9)
    ];

    uint256[10] public anvilPrivateKeys = [
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80, // Admin (0)
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d, // (1)
        0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a, // (2)
        0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6, // (3)
        0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a, // (4)
        0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba, // (5)
        0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e, // (6)
        0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356, // (7)
        0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97, // (8)
        0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6  // (9)
    ];


    string[] public constituencies = [
        "Westminster North",
        "Islington South",
        "Birmingham Edgbaston",
        "Manchester Central",
        "Edinburgh South",
        "Cardiff West",
        "Belfast South",
        "Glasgow North",
        "Sheffield Central",
        "Norwich South"
    ];

    string[] public parties = [
        "Conservative",
        "Labour",
        "Liberal Democrats",
        "Scottish National Party",
        "Green Party",
        "Plaid Cymru",
        "Democratic Unionist Party",
        "Sinn Fein",
        "Alliance Party",
        "Independent"
    ];

    string[] public names = [
        "John Smith",
        "Mary Johnson",
        "David Williams",
        "Sarah Brown",
        "James Wilson",
        "Emma Jones",
        "Michael Davies",
        "Elizabeth Taylor",
        "Robert Evans",
        "Jennifer Thomas"
    ];

    function setUp() public {}

    function run() public {
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        address votingAddress = vm.envAddress("VOTING_ADDRESS");
        uint256 adminPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(adminPrivateKey);

        console.log("=== Using Existing MP Token System for Anvil ===");
        
        MPTokenFactory factory = MPTokenFactory(factoryAddress);
        MPVoting votingContract = MPVoting(votingAddress);
        
        console.log("MPTokenFactory address:", factoryAddress);
        console.log("MPToken address:", factory.getMPTokenAddress());
        console.log("MPVoting address:", votingAddress);
        
        uint256 currentMPCount = factory.getMPTokenCount();
        uint256 currentQuestionCount = votingContract.questionCount();
        console.log("Current MP count:", currentMPCount);
        console.log("Current question count:", currentQuestionCount);
        
        console.log("\n=== Creating MP Tokens for Anvil Accounts ===");
        
        uint256 currentYear = 2024;
        uint256 fourYearsFromNow = block.timestamp + (4 * 365 days);
        
        for (uint256 i = 1; i < anvilAccounts.length; i++) {
            address recipient = anvilAccounts[i];
            string memory name = names[i % names.length];
            string memory party = parties[i % parties.length];
            string memory constituency = constituencies[i % constituencies.length];
            
            uint256 tokenId = factory.createMPToken(
                recipient,
                name,
                party,
                constituency,
                currentYear,
                fourYearsFromNow
            );
            
            console.log(
                string(
                    abi.encodePacked(
                        "Created MP Token #",
                        vm.toString(tokenId),
                        " for ",
                        name,
                        " (",
                        party,
                        ", ",
                        constituency,
                        ") at address ",
                        vm.toString(recipient)
                    )
                )
            );
        }
        

        factory.addAdmin(anvilAccounts[1]);
        votingContract.addAdmin(anvilAccounts[1]);
        console.log("\nAdded account 1 as admin for both contracts:", anvilAccounts[1]);
        

        console.log("\n=== Creating Voting Questions with Staking ===");
        
        uint256 startTime = block.timestamp + 2 minutes;  
        uint256 endTime = block.timestamp + 10 minutes;      
        
        uint256 questionId1 = votingContract.createQuestion(
            "Should the new environmental protection bill be passed?",
            startTime,
            endTime
        );
        
        uint256 questionId2 = votingContract.createQuestion(
            "Do you support the proposed education reform?",
            startTime,
            endTime
        );
        
        uint256 questionId3 = votingContract.createQuestion(
            "Should the government increase funding for renewable energy?",
            startTime,
            endTime
        );
        
        console.log("\n=== Created Voting Questions with Staking ===");
        console.log("Question 1 ID:", questionId1, "- Environmental Bill");
        console.log("Question 2 ID:", questionId2, "- Education Reform");
        console.log("Question 3 ID:", questionId3, "- Renewable Energy");
        console.log("Options: Yes (0), No (1), Abstain (2)");
        console.log("Required stake: 100 ETH per vote");
        console.log("Vault owner (question creator):", anvilAccounts[0]);
        console.log("Start time:", startTime);
        console.log("End time:", endTime);
        
        console.log("\n=== Staking Mechanism Rules ===");
        console.log("- Each voter must stake 100 ETH to vote");
        console.log("- Winners get their full stake back");
        console.log("- Losers get 50% of their stake back");
        console.log("- The remaining 50% from losers goes to the vault (question creator)");
        
        console.log("\n=== Final Status ===");
        console.log("Total MP Tokens:", factory.getMPTokenCount());
        console.log("Total Questions:", votingContract.questionCount());
        
        console.log("\n=== Ready for Staking Demonstration! ===");
        console.log("Wait 2 minutes, then start voting with 100 ETH stakes");
        console.log("\nExample vote command:");
        console.log("cast send", votingAddress, "\"vote(uint256,uint256)\" 1 0 --value 100ether \\");
        console.log("--private-key", vm.toString(anvilPrivateKeys[1]), "--rpc-url http://localhost:8545");
        
        vm.stopBroadcast();
    }
}


contract DemoVotingWithStakes is Script {
    address votingContractAddress;
    
    function setUp() public {
        votingContractAddress = vm.envAddress("VOTING_ADDRESS");
    }
    
    function run() public {
        MPVoting votingContract = MPVoting(votingContractAddress);
        
        console.log("=== Demo: Voting with Stakes ===");
        

        for (uint256 i = 1; i <= 5; i++) {
            uint256 privateKey = uint256(keccak256(abi.encodePacked("test", i)));
            vm.startBroadcast(privateKey);
            
            address voter = vm.addr(privateKey);
            console.log("Voting from account:", voter);

            uint256 option = i % 2;
            
            try votingContract.vote{value: 100 ether}(1, option) {
                console.log("Successfully voted for option:", option);
                console.log("Staked 100 ETH");
            } catch Error(string memory reason) {
                console.log("Voting failed:", reason);
            }
            
            vm.stopBroadcast();
        }
    }
}