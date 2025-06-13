// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/MPVoting.sol";

contract DeployMPVoting is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("MP_FACTORY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        MPVoting votingContract = new MPVoting(factoryAddress);
        
        console.log("=== MP Voting Contract Deployment Complete ===");
        console.log("MPVoting deployed at:", address(votingContract));
        console.log("Using MPTokenFactory at:", factoryAddress);
        console.log("Deployer address (owner/admin):", vm.addr(deployerPrivateKey));
        
        address deployer = vm.addr(deployerPrivateKey);
        bool isAdmin = votingContract.isAdmin(deployer);
        console.log("Deployer is admin:", isAdmin);
        
        console.log("\n=== Next Steps ===");
        console.log("1. Update your frontend configuration with the voting contract address");
        console.log("2. Use the admin panel to add voting questions");
        console.log("3. Allow MPs to vote through the web interface");
        
        console.log("\n=== Contract Verification Commands ===");
        console.log("MPVoting verification:");

        vm.stopBroadcast();
    }
}

contract AddVotingAdmins is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address votingAddress = vm.envAddress("MP_VOTING_ADDRESS");
        
        address[] memory newAdmins = new address[](2);
        newAdmins[0] = vm.envAddress("VOTING_ADMIN_1");
        newAdmins[1] = vm.envAddress("VOTING_ADMIN_2"); 
        
        vm.startBroadcast(deployerPrivateKey);

        MPVoting votingContract = MPVoting(votingAddress);
        
        console.log("Adding admins to voting contract at:", votingAddress);
        
        for (uint i = 0; i < newAdmins.length; i++) {
            if (newAdmins[i] != address(0)) {
                console.log("Adding admin:", newAdmins[i]);
                votingContract.addAdmin(newAdmins[i]);
                bool isAdmin = votingContract.isAdmin(newAdmins[i]);
                console.log("Verification - Is admin:", isAdmin);
            }
        }
        
        console.log("Admin addition complete!");

        vm.stopBroadcast();
    }
}