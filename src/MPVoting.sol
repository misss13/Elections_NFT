// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MPToken.sol";
import "./MPTokenFactory.sol";

contract MPVoting is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    MPTokenFactory public mpTokenFactory;
    MPToken public mpToken;
    
    uint256 public constant STAKE_AMOUNT = 100 ether;
    uint256 public constant LOSER_RETURN_PERCENTAGE = 50;
    
    struct Question {
        string question;
        string[] options;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool isSettled;
        bool isDraw;
        uint256 totalVotes;
        address vault;
        uint256 winningOption;
        uint256 totalStaked;
        uint256[] tiedOptions;
        mapping(uint256 => uint256) optionVotes; 
        mapping(address => bool) hasVoted;      
        mapping(address => uint256) voterChoice; 
        mapping(address => uint256) voterStake;
        mapping(address => bool) stakeReturned;
    }
    
    uint256 public questionCount;
    mapping(uint256 => Question) public questions;
    
    event QuestionCreated(uint256 indexed questionId, string question, uint256 startTime, uint256 endTime, address vault);
    event QuestionUpdated(uint256 indexed questionId, string question, bool isActive);
    event VoteCast(uint256 indexed questionId, address indexed voter, uint256 option, uint256 stake);
    event QuestionClosed(uint256 indexed questionId, uint256 totalVotes, uint256 winningOption);
    event QuestionClosedWithDraw(uint256 indexed questionId, uint256 totalVotes, uint256[] tiedOptions);
    event StakeReturned(uint256 indexed questionId, address indexed voter, uint256 amount);
    event VaultEarnings(uint256 indexed questionId, address indexed vault, uint256 amount);
    event QuestionSettled(uint256 indexed questionId, uint256 totalDistributed);
    
    constructor(address _mpTokenFactoryAddress) {
        require(_mpTokenFactoryAddress != address(0), "Invalid MP Token Factory address");
        mpTokenFactory = MPTokenFactory(_mpTokenFactoryAddress);
        address mpTokenAddress = mpTokenFactory.getMPTokenAddress();
        mpToken = MPToken(mpTokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }
    
    function addAdmin(address admin) public onlyAdmin {
        _grantRole(ADMIN_ROLE, admin);
    }
    
    function removeAdmin(address admin) public onlyAdmin {
        _revokeRole(ADMIN_ROLE, admin);
    }
    
    function isAdmin(address account) public view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }
    
    function createQuestion(
        string memory _question,
        uint256 _startTime,
        uint256 _endTime
    ) public onlyAdmin returns (uint256) {
        require(_endTime > _startTime, "End time must be after start time");
        require(_startTime > block.timestamp, "Start time must be in the future");
        
        questionCount++;
        uint256 questionId = questionCount;
        
        Question storage newQuestion = questions[questionId];
        newQuestion.question = _question;
        newQuestion.startTime = _startTime;
        newQuestion.endTime = _endTime;
        newQuestion.isActive = true;
        newQuestion.isSettled = false;
        newQuestion.isDraw = false;
        newQuestion.vault = msg.sender;
        newQuestion.totalVotes = 0;
        newQuestion.totalStaked = 0;
        
        newQuestion.options.push("Yes");
        newQuestion.options.push("No");
        newQuestion.options.push("Abstain");
        
        emit QuestionCreated(questionId, _question, _startTime, _endTime, msg.sender);
        return questionId;
    }
    
    function updateQuestion(
        uint256 _questionId,
        string memory _question
    ) public onlyAdmin {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        require(q.startTime > block.timestamp, "Voting has already started");
        require(q.isActive, "Question is not active");
        
        q.question = _question;
        emit QuestionUpdated(_questionId, _question, q.isActive);
    }
    
    function vote(uint256 _questionId, uint256 _optionIndex) public payable nonReentrant {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        require(q.isActive, "Question is not active");
        require(block.timestamp >= q.startTime, "Voting has not started yet");
        require(block.timestamp <= q.endTime, "Voting has ended");
        require(_optionIndex < q.options.length, "Invalid option index");
        require(!q.hasVoted[msg.sender], "Already voted");
        require(isValidMPVoter(msg.sender), "Not a valid MP voter");
        require(msg.value == STAKE_AMOUNT, "Must stake exactly 100 ETH");
        
        q.optionVotes[_optionIndex]++;
        q.totalVotes++;
        q.hasVoted[msg.sender] = true;
        q.voterChoice[msg.sender] = _optionIndex;
        q.voterStake[msg.sender] = msg.value;
        q.totalStaked += msg.value;
        
        emit VoteCast(_questionId, msg.sender, _optionIndex, msg.value);
    }
    
    function closeQuestion(uint256 _questionId) public {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        require(q.isActive, "Question already inactive");
        require(block.timestamp > q.endTime, "Voting period not over yet");
        require(!q.isSettled, "Question already settled");
        
        uint256 maxVotes = 0;
        for (uint256 i = 0; i < q.options.length; i++) {
            if (q.optionVotes[i] > maxVotes) {
                maxVotes = q.optionVotes[i];
            }
        }
        
        uint256 tiedCount = 0;
        for (uint256 i = 0; i < q.options.length; i++) {
            if (q.optionVotes[i] == maxVotes) {
                tiedCount++;
            }
        }
        
        if (tiedCount > 1) {
            q.isDraw = true;
            q.winningOption = type(uint256).max;
            
            for (uint256 i = 0; i < q.options.length; i++) {
                if (q.optionVotes[i] == maxVotes) {
                    q.tiedOptions.push(i);
                }
            }
            
            emit QuestionClosedWithDraw(_questionId, q.totalVotes, q.tiedOptions);
        } else {
            q.isDraw = false;
            for (uint256 i = 0; i < q.options.length; i++) {
                if (q.optionVotes[i] == maxVotes) {
                    q.winningOption = i;
                    break;
                }
            }
            
            emit QuestionClosed(_questionId, q.totalVotes, q.winningOption);
        }
        
        q.isActive = false;
    }
    
    function settleStakes(uint256 _questionId) public onlyAdmin nonReentrant {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        require(!q.isActive, "Question must be closed first");
        require(!q.isSettled, "Stakes already settled");
        require(q.totalVotes > 0, "No votes to settle");
        
        q.isSettled = true;
        emit QuestionSettled(_questionId, q.totalStaked);
    }
    
    function claimStake(uint256 _questionId) public nonReentrant {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        require(!q.isActive, "Voting still active");
        require(q.hasVoted[msg.sender], "Did not vote on this question");
        require(!q.stakeReturned[msg.sender], "Stake already returned");
        require(q.voterStake[msg.sender] > 0, "No stake to claim");
        
        uint256 stakeAmount = q.voterStake[msg.sender];
        uint256 returnAmount;
        
        if (q.isDraw) {
            returnAmount = stakeAmount;
        } else if (q.voterChoice[msg.sender] == q.winningOption) {
            returnAmount = stakeAmount;
        } else {
            returnAmount = (stakeAmount * LOSER_RETURN_PERCENTAGE) / 100;
            
            uint256 vaultAmount = stakeAmount - returnAmount;
            (bool vaultSuccess, ) = q.vault.call{value: vaultAmount}("");
            require(vaultSuccess, "Vault transfer failed");
            emit VaultEarnings(_questionId, q.vault, vaultAmount);
        }
        
        q.stakeReturned[msg.sender] = true;
        
        (bool success, ) = msg.sender.call{value: returnAmount}("");
        require(success, "Stake return failed");
        
        emit StakeReturned(_questionId, msg.sender, returnAmount);
    }
    
    function getStakeInfo(uint256 _questionId, address _voter) public view returns (
        uint256 staked,
        bool returned,
        bool canClaim
    ) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        
        staked = q.voterStake[_voter];
        returned = q.stakeReturned[_voter];
        canClaim = !q.isActive && q.hasVoted[_voter] && !q.stakeReturned[_voter] && q.voterStake[_voter] > 0;
        
        return (staked, returned, canClaim);
    }
    
    function getQuestionDetails(uint256 _questionId) public view returns (
        string memory question,
        string[] memory options,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        uint256 totalVotes,
        address vault,
        uint256 totalStaked,
        uint256 winningOption
    ) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        return (
            q.question,
            q.options,
            q.startTime,
            q.endTime,
            q.isActive,
            q.totalVotes,
            q.vault,
            q.totalStaked,
            q.winningOption
        );
    }
    
    function getTiedOptions(uint256 _questionId) public view returns (uint256[] memory tiedOptions) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        return q.tiedOptions;
    }
    
    function isQuestionDraw(uint256 _questionId) public view returns (bool isDraw) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        return q.isDraw;
    }
    
    function getOptionVoteCount(uint256 _questionId, uint256 _optionIndex) public view returns (uint256 voteCount) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        require(_optionIndex < q.options.length, "Invalid option index");
        return q.optionVotes[_optionIndex];
    }

    function getYesVotesCount(uint256 _questionId) public view returns (uint256 yes_counts) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        return q.optionVotes[0];
    }

    function getNoVotesCount(uint256 _questionId) public view returns (uint256 no_counts) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        return q.optionVotes[1];
    }
    
    function getVotingResults(uint256 _questionId) public view returns (bool results) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        require(!q.isActive, "Voting not ended yet. Results will be available after the voting");
        
        if (q.isDraw) {
            return false;
        }
        
        return q.winningOption == 0;
    }

    function getDetailedVotingResults(uint256 _questionId) public view returns (
        bool isDraw,
        bool yesWon,
        bool noWon,
        uint256 winningOption
    ) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        require(!q.isActive, "Voting not ended yet. Results will be available after the voting");
        
        isDraw = q.isDraw;
        winningOption = q.winningOption;
        
        if (isDraw) {
            yesWon = false;
            noWon = false;
        } else {
            yesWon = (q.winningOption == 0);
            noWon = (q.winningOption == 1);
        }
        
        return (isDraw, yesWon, noWon, winningOption);
    }
    
    function getAllVoteCounts(uint256 _questionId) public view returns (uint256[] memory voteCounts) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        uint256[] memory counts = new uint256[](q.options.length);
        for (uint256 i = 0; i < q.options.length; i++) {
            counts[i] = q.optionVotes[i];
        }
        return counts;
    }
    
    function checkVote(uint256 _questionId, address _voter) public view returns (bool hasVoted, uint256 optionIndex) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        return (q.hasVoted[_voter], q.voterChoice[_voter]);
    }
    
    function isValidMPVoter(address _voter) public view returns (bool isValid) {
        uint256 balance = mpToken.balanceOf(_voter);
        if (balance == 0) {
            return false;
        }
        
        uint256 totalMPs = mpTokenFactory.getMPTokenCount();
        
        for (uint256 i = 1; i <= totalMPs; i++) {
            try mpToken.ownerOf(i) returns (address owner) {
                if (owner == _voter) {
                    try mpTokenFactory.getMPTokenData(i) returns (MPToken.MPData memory data) {
                        bool isExpired = mpTokenFactory.isTokenExpired(i);
                        if (data.isActive && !isExpired) {
                            return true;
                        }
                    } catch {
                        continue;
                    }
                }
            } catch {
                continue;
            }
        }
        
        return false;
    }
    
    function getActiveQuestions() public view returns (uint256[] memory activeQuestionIds) {
        uint256 activeCount = 0;
        
        for (uint256 i = 1; i <= questionCount; i++) {
            if (questions[i].isActive && 
                questions[i].startTime <= block.timestamp && 
                questions[i].endTime >= block.timestamp) {
                activeCount++;
            }
        }
        
        uint256[] memory activeIds = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i <= questionCount; i++) {
            if (questions[i].isActive && 
                questions[i].startTime <= block.timestamp && 
                questions[i].endTime >= block.timestamp) {
                activeIds[index] = i;
                index++;
            }
        }
        
        return activeIds;
    }
    
    function emergencyWithdraw() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Withdrawal failed");
    }
}
