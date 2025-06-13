// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MPToken.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MPTokenFactory is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    MPToken public mpToken;
    
    event MPTokenFactoryDeployed(address indexed mpTokenAddress);
    event NewMPTokenMinted(uint256 indexed tokenId, string name, address recipient, uint256 expirationDate);
    event ExpiredMPTokenDestroyed(uint256 indexed tokenId);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        
        mpToken = new MPToken();
        emit MPTokenFactoryDeployed(address(mpToken));
    }
    
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    modifier onlyOwner() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not the owner");
        _;
    }

    function addAdmin(address admin) public onlyOwner {
        _grantRole(ADMIN_ROLE, admin);
        mpToken.addAdmin(admin);
        emit AdminAdded(admin);
    }

    function removeAdmin(address admin) public onlyOwner {
        _revokeRole(ADMIN_ROLE, admin);
        mpToken.removeAdmin(admin);
        emit AdminRemoved(admin);
    }

    function isAdmin(address account) public view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }
    

    function createMPToken(
        address recipient,
        string memory name,
        string memory party,
        string memory constituency,
        uint256 electionYear,
        uint256 expirationDate
    ) public onlyAdmin returns (uint256) {
        uint256 tokenId = mpToken.mintMPToken(
            recipient,
            name,
            party,
            constituency,
            electionYear,
            expirationDate
        );
        
        emit NewMPTokenMinted(tokenId, name, recipient, expirationDate);
        
        return tokenId;
    }
    
    function updateMPTokenStatus(uint256 tokenId, bool isActive) public onlyAdmin {
        mpToken.updateMPStatus(tokenId, isActive);
    }
    
    function getMPTokenData(uint256 tokenId) public view returns (MPToken.MPData memory) {
        return mpToken.getMPData(tokenId);
    }
    
    function getMPTokenCount() public view returns (uint256) {
        return mpToken.getMPCount();
    }
    
    function getMPTokenAddress() public view returns (address) {
        return address(mpToken);
    }
    
    function destroyExpiredMPToken(uint256 tokenId) public onlyAdmin {
        require(mpToken.isExpired(tokenId), "Token has not expired yet");
        mpToken.destroyExpiredToken(tokenId);
        emit ExpiredMPTokenDestroyed(tokenId);
    }
    
    function isTokenExpired(uint256 tokenId) public view returns (bool) {
        return mpToken.isExpired(tokenId);
    }
}