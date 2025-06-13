// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MPToken is ERC721, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 private _tokenIds;

    struct MPData {
        string name;
        string party;
        string constituency;
        uint256 electionYear;
        bool isActive;
        uint256 expirationDate; 
    }

    mapping(uint256 => MPData) public mpData;

    event MPTokenMinted(uint256 indexed tokenId, string name, string party, string constituency, uint256 expirationDate);
    event MPStatusChanged(uint256 indexed tokenId, bool isActive);
    event MPTokenExpired(uint256 indexed tokenId, string name);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);

    constructor() ERC721("Member of Parliament ID", "MPID") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
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
        emit AdminAdded(admin);
    }

    function removeAdmin(address admin) public onlyOwner {
        _revokeRole(ADMIN_ROLE, admin);
        emit AdminRemoved(admin);
    }

    function isAdmin(address account) public view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    function mintMPToken(
        address recipient,
        string memory name,
        string memory party,
        string memory constituency,
        uint256 electionYear,
        uint256 expirationDate
    ) public onlyAdmin returns (uint256) {
        require(expirationDate > block.timestamp, "Expiration date must be in the future");
        
        _tokenIds++;
        uint256 newTokenId = _tokenIds;
        
        _safeMint(recipient, newTokenId);
        
        mpData[newTokenId] = MPData({
            name: name,
            party: party,
            constituency: constituency,
            electionYear: electionYear,
            isActive: true,
            expirationDate: expirationDate
        });

        emit MPTokenMinted(newTokenId, name, party, constituency, expirationDate);
        
        return newTokenId;
    }

    function updateMPStatus(uint256 tokenId, bool isActive) public onlyAdmin {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        mpData[tokenId].isActive = isActive;
        
        emit MPStatusChanged(tokenId, isActive);
    }

    function getMPData(uint256 tokenId) public view returns (MPData memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return mpData[tokenId];
    }

    function getMPCount() public view returns (uint256) {
        return _tokenIds;
    }

    function destroyExpiredToken(uint256 tokenId) public onlyAdmin {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(block.timestamp > mpData[tokenId].expirationDate, "Token has not expired yet");
        
        string memory name = mpData[tokenId].name;
        
        _burn(tokenId);
        
        emit MPTokenExpired(tokenId, name);
    }

    function isExpired(uint256 tokenId) public view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return block.timestamp > mpData[tokenId].expirationDate;
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}