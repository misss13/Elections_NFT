// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/MPTokenFactory.sol";

contract DeployMPTokenFactory is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MPTokenFactory factory = new MPTokenFactory();
        

        console.log("=== MP ID Platform Deployment Complete ===");
        console.log("MPTokenFactory deployed at:", address(factory));
        console.log("MPToken deployed at:", factory.getMPTokenAddress());
        console.log("Deployer address (owner/admin):", vm.addr(deployerPrivateKey));
        
        // Verify admin status
        address deployer = vm.addr(deployerPrivateKey);
        bool isAdmin = factory.isAdmin(deployer);
        console.log("Deployer is admin:", isAdmin);
        
        console.log("\n=== Next Steps ===");
        console.log("1. Update your frontend configuration with the factory address:", address(factory));
        console.log("2. Use the admin panel to add additional admins if needed");
        console.log("3. Start creating MP ID tokens through the web interface");
        
        console.log("\n=== Contract Verification Commands ===");
        console.log("MPTokenFactory verification:");
        console.log("forge verify-contract", address(factory), "src/MPTokenFactory.sol:MPTokenFactory --chain-id <your-chain-id>");
        
        address mpTokenAddress = factory.getMPTokenAddress();
        console.log("\nMPToken verification:");
        console.log("forge verify-contract", mpTokenAddress, "src/MPToken.sol:MPToken --chain-id <your-chain-id>");

        vm.stopBroadcast();
    }
}

contract AddAdmins is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        
        address[] memory newAdmins = new address[](2);
        newAdmins[0] = vm.envAddress("ADMIN_1"); 
        newAdmins[1] = vm.envAddress("ADMIN_2"); 
        
        vm.startBroadcast(deployerPrivateKey);

        MPTokenFactory factory = MPTokenFactory(factoryAddress);
        
        console.log("Adding admins to factory at:", factoryAddress);
        
        for (uint i = 0; i < newAdmins.length; i++) {
            if (newAdmins[i] != address(0)) {
                console.log("Adding admin:", newAdmins[i]);
                factory.addAdmin(newAdmins[i]);

                bool isAdmin = factory.isAdmin(newAdmins[i]);
                console.log("Verification - Is admin:", isAdmin);
            }
        }
        
        console.log("Admin addition complete!");

        vm.stopBroadcast();
    }
}

contract RemoveAdmins is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");

        address[] memory adminsToRemove = new address[](1);
        adminsToRemove[0] = vm.envAddress("ADMIN_TO_REMOVE"); 
        
        vm.startBroadcast(deployerPrivateKey);

        MPTokenFactory factory = MPTokenFactory(factoryAddress);
        
        console.log("Removing admins from factory at:", factoryAddress);
        
        for (uint i = 0; i < adminsToRemove.length; i++) {
            if (adminsToRemove[i] != address(0)) {
                console.log("Removing admin:", adminsToRemove[i]);
                factory.removeAdmin(adminsToRemove[i]);
                

                bool isAdmin = factory.isAdmin(adminsToRemove[i]);
                console.log("Verification - Is still admin:", isAdmin);
            }
        }
        
        console.log("Admin removal complete!");

        vm.stopBroadcast();
    }
}


contract CreateMPTokens is Script {
    function setUp() public {}

    function run() public {
        uint256 adminPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        

        string memory recipientsEnv = vm.envString("RECIPIENTS");
        string[] memory recipientStrs = splitString(recipientsEnv, ",");
        
        address[] memory recipients = new address[](recipientStrs.length);
        for (uint i = 0; i < recipientStrs.length; i++) {
            recipients[i] = vm.parseAddress(recipientStrs[i]);
        }
        
 
        string[] memory names = splitString(vm.envString("MP_NAMES"), ",");
        string[] memory parties = splitString(vm.envString("MP_PARTIES"), ",");
        string[] memory constituencies = splitString(vm.envString("MP_CONSTITUENCIES"), ",");
        
        require(names.length == recipients.length, "Names count must match recipients count");
        require(parties.length == recipients.length, "Parties count must match recipients count");
        require(constituencies.length == recipients.length, "Constituencies count must match recipients count");
        
        uint256 currentYear = 2024;
        uint256 expirationDate = block.timestamp + (4 * 365 days);
        
        vm.startBroadcast(adminPrivateKey);
        
        MPTokenFactory factory = MPTokenFactory(factoryAddress);
        
        console.log("Creating MP Tokens using factory at:", factoryAddress);
        
        for (uint i = 0; i < recipients.length; i++) {
            console.log(
                string(
                    abi.encodePacked(
                        "Creating MP Token for ",
                        names[i],
                        " (",
                        parties[i],
                        ", ",
                        constituencies[i],
                        ") at address ",
                        vm.toString(recipients[i])
                    )
                )
            );
            

            uint256 tokenId = factory.createMPToken(
                recipients[i],
                names[i],
                parties[i],
                constituencies[i],
                currentYear,
                expirationDate
            );
            
            console.log("Created MP Token with ID:", tokenId);
        }
        
        console.log("MP Token creation complete!");
        
        vm.stopBroadcast();
    }
    

    function splitString(string memory str, string memory delimiter) internal pure returns (string[] memory) {
        uint count = 1;
        for (uint i = 0; i < bytes(str).length; i++) {
            if (bytes(str)[i] == bytes(delimiter)[0]) {
                count++;
            }
        }
        
        string[] memory result = new string[](count);
        uint index = 0;
        
        bytes memory strBytes = bytes(str);
        uint lastIndex = 0;
        
        for (uint i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == bytes(delimiter)[0]) {
                result[index] = substring(str, lastIndex, i);
                lastIndex = i + 1;
                index++;
            }
        }

        result[index] = substring(str, lastIndex, strBytes.length);
        
        return result;
    }
    

    function substring(string memory str, uint startIndex, uint endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        
        for (uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        
        return string(result);
    }
}