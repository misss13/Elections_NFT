// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MPToken.sol";
import "./MPTokenFactory.sol";

/**
 * @title MPVoting
 * @notice A voting system for MPs who hold MP ID NFTs with staking mechanism and draw handling
 * 
 */
contract MPVoting is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    MPTokenFactory public mpTokenFactory;
    MPToken public mpToken;
    
    uint256 public constant STAKE_AMOUNT = 100 ether;
    uint256 public constant LOSER_RETURN_PERCENTAGE = 50; // 50% return for losers
    
    struct Question {
        string question;
        string[] options;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool isSettled; // Whether stakes have been distributed
        bool isDraw; // Whether the result is a draw
        uint256 totalVotes;
        address vault; // The admin who created the question (vault owner)
        uint256 winningOption; // Set after voting ends (meaningless if isDraw is true)
        uint256 totalStaked; // Total amount staked
        uint256[] tiedOptions; // Array of options that are tied (used when isDraw is true)
        mapping(uint256 => uint256) optionVotes; 
        mapping(address => bool) hasVoted;      
        mapping(address => uint256) voterChoice; 
        mapping(address => uint256) voterStake; // Track each voter's stake
        mapping(address => bool) stakeReturned; // Track if stake has been returned
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
    
    /**
     * @notice Constructor that sets up the contract with the MP Token Factory
     * @param _mpTokenFactoryAddress Address of the MP Token Factory contract
     */
    constructor(address _mpTokenFactoryAddress) {
        require(_mpTokenFactoryAddress != address(0), "Invalid MP Token Factory address");
        mpTokenFactory = MPTokenFactory(_mpTokenFactoryAddress);
        address mpTokenAddress = mpTokenFactory.getMPTokenAddress();
        mpToken = MPToken(mpTokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @notice Modifier to ensure only admins can call a function
     */
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }
    
    /**
     * @notice Add an admin to the contract
     * @param admin Address to add as admin
     */
    function addAdmin(address admin) public onlyAdmin {
        _grantRole(ADMIN_ROLE, admin);
    }
    
    /**
     * @notice Remove an admin from the contract
     * @param admin Address to remove as admin
     */
    function removeAdmin(address admin) public onlyAdmin {
        _revokeRole(ADMIN_ROLE, admin);
    }
    
    /**
     * @notice Check if an address is an admin
     * @param account Address to check
     * @return bool True if the address is an admin
     */
    function isAdmin(address account) public view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }
    
    /**
     * @notice Create a new voting question
     * @param _question The question text
     * @param _startTime When voting starts (unix timestamp)
     * @param _endTime When voting ends (unix timestamp)
     * @return questionId The ID of the newly created question
     */
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
        newQuestion.vault = msg.sender; // The creator becomes the vault
        newQuestion.totalVotes = 0;
        newQuestion.totalStaked = 0;
        
        // Initialize options
        newQuestion.options.push("Yes");
        newQuestion.options.push("No");
        newQuestion.options.push("Abstain");
        
        emit QuestionCreated(questionId, _question, _startTime, _endTime, msg.sender);
        return questionId;
    }
    
    /**
     * @notice Update a question (only before voting begins)
     * @param _questionId The ID of the question to update
     * @param _question New question text
     */
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
    
    /**
     * @notice Cast a vote on a question with stake
     * @param _questionId The question ID to vote on
     * @param _optionIndex The index of the option to vote for
     */
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
        
        // Record the vote
        q.optionVotes[_optionIndex]++;
        q.totalVotes++;
        q.hasVoted[msg.sender] = true;
        q.voterChoice[msg.sender] = _optionIndex;
        q.voterStake[msg.sender] = msg.value;
        q.totalStaked += msg.value;
        
        emit VoteCast(_questionId, msg.sender, _optionIndex, msg.value);
    }
    
    /**
     * @notice Close a question after voting ends and determine the winner or draw
     * @param _questionId The ID of the question to close
     */
    function closeQuestion(uint256 _questionId) public onlyAdmin {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        require(q.isActive, "Question already inactive");
        require(block.timestamp > q.endTime, "Voting period not over yet");
        require(!q.isSettled, "Question already settled");
        
        // Find the maximum vote count
        uint256 maxVotes = 0;
        for (uint256 i = 0; i < q.options.length; i++) {
            if (q.optionVotes[i] > maxVotes) {
                maxVotes = q.optionVotes[i];
            }
        }
        
        // Count how many options have the maximum votes
        uint256 tiedCount = 0;
        for (uint256 i = 0; i < q.options.length; i++) {
            if (q.optionVotes[i] == maxVotes) {
                tiedCount++;
            }
        }
        
        if (tiedCount > 1) {
            // It's a draw
            q.isDraw = true;
            q.winningOption = type(uint256).max; // Set to max value to indicate no winner
            
            // Store tied options
            for (uint256 i = 0; i < q.options.length; i++) {
                if (q.optionVotes[i] == maxVotes) {
                    q.tiedOptions.push(i);
                }
            }
            
            emit QuestionClosedWithDraw(_questionId, q.totalVotes, q.tiedOptions);
        } else {
            // Clear winner
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
    
    /**
     * @notice Claim stake back after voting ends
     * @param _questionId The ID of the question
     */
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
            // In case of a draw, everyone gets their full stake back
            returnAmount = stakeAmount;
        } else if (q.voterChoice[msg.sender] == q.winningOption) {
            // Winner gets full stake back
            returnAmount = stakeAmount;
        } else {
            // Loser gets 50% back
            returnAmount = (stakeAmount * LOSER_RETURN_PERCENTAGE) / 100;
            
            // Vault gets the remaining 50%
            uint256 vaultAmount = stakeAmount - returnAmount;
            (bool vaultSuccess, ) = q.vault.call{value: vaultAmount}("");
            require(vaultSuccess, "Vault transfer failed");
            emit VaultEarnings(_questionId, q.vault, vaultAmount);
        }
        
        q.stakeReturned[msg.sender] = true;
        
        // Return stake to voter
        (bool success, ) = msg.sender.call{value: returnAmount}("");
        require(success, "Stake return failed");
        
        emit StakeReturned(_questionId, msg.sender, returnAmount);
    }
    
    /**
     * @notice Get stake information for a voter
     * @param _questionId The question ID
     * @param _voter The voter address
     * @return staked Amount staked
     * @return returned Whether stake has been returned
     * @return canClaim Whether the voter can claim their stake
     */
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
    
    /**
     * @notice Get details of a question including stake info and draw status
     * @param _questionId The question ID
     * @return question The question text
     * @return options The answer options
     * @return startTime When voting starts
     * @return endTime When voting ends
     * @return isActive Whether the question is active
     * @return totalVotes Total number of votes cast
     * @return vault The vault owner address
     * @return totalStaked Total amount staked
     * @return winningOption The winning option (max uint256 if draw)
     * @return isDraw Whether the result is a draw
     */
    function getQuestionDetails(uint256 _questionId) public view returns (
        string memory question,
        string[] memory options,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        uint256 totalVotes,
        address vault,
        uint256 totalStaked,
        uint256 winningOption,
        bool isDraw
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
            q.winningOption,
            q.isDraw
        );
    }
    
    /**
     * @notice Get the tied options in case of a draw
     * @param _questionId The question ID
     * @return tiedOptions Array of option indices that are tied
     */
    function getTiedOptions(uint256 _questionId) public view returns (uint256[] memory tiedOptions) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        return q.tiedOptions;
    }
    
    /**
     * @notice Check if a question resulted in a draw
     * @param _questionId The question ID
     * @return isDraw True if the question resulted in a draw
     */
    function isQuestionDraw(uint256 _questionId) public view returns (bool isDraw) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        return q.isDraw;
    }
    
    /**
     * @notice Get vote count for a specific option
     * @param _questionId The question ID
     * @param _optionIndex The option index
     * @return voteCount Number of votes for the option
     */
    function getOptionVoteCount(uint256 _questionId, uint256 _optionIndex) public view returns (uint256 voteCount) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        require(_optionIndex < q.options.length, "Invalid option index");
        return q.optionVotes[_optionIndex];
    }

    /**
     * @notice Return all yes votes
     * @param _questionId The question ID
     * @return yes_counts number of votes which supported question
     */
    function getYesVotesCount(uint256 _questionId) public view returns (uint256 yes_counts) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        return q.optionVotes[0];
    }

    /**
     * @notice Return all no votes
     * @param _questionId The question ID
     * @return no_counts number of votes which opposed question
     */
    function getNoVotesCount(uint256 _questionId) public view returns (uint256 no_counts) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        return q.optionVotes[1];
    }
    
    /**
     * @notice Return voting results
     * @param _questionId The question ID
     * @return results true if Yes won, false if No won or draw occurred
     */
    function getVotingResults(uint256 _questionId) public view returns (bool results) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        require(!q.isActive, "Voting not ended yet. Results will be available after the voting");
        
        // Return false if it's a draw or if No won
        if (q.isDraw) {
            return false;
        }
        
        return q.winningOption == 0; // 0 is "Yes" option
    }

    /**
     * @notice Get detailed voting results including draw status
     * @param _questionId The question ID
     * @return isDraw Whether the result is a draw
     * @return yesWon Whether "Yes" won (only meaningful if not a draw)
     * @return noWon Whether "No" won (only meaningful if not a draw)
     * @return winningOption The winning option index (max uint256 if draw)
     */
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
    
    /**
     * @notice Get all vote counts for a question
     * @param _questionId The question ID
     * @return voteCounts Array of vote counts for each option
     */
    function getAllVoteCounts(uint256 _questionId) public view returns (uint256[] memory voteCounts) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        uint256[] memory counts = new uint256[](q.options.length);
        for (uint256 i = 0; i < q.options.length; i++) {
            counts[i] = q.optionVotes[i];
        }
        return counts;
    }
    
    /**
     * @notice Check if an address has voted on a question
     * @param _questionId The question ID
     * @param _voter The address to check
     * @return hasVoted True if the address has voted
     * @return optionIndex The index of the option they voted for (0 if not voted)
     */
    function checkVote(uint256 _questionId, address _voter) public view returns (bool hasVoted, uint256 optionIndex) {
        require(_questionId <= questionCount && _questionId > 0, "Invalid question ID");
        Question storage q = questions[_questionId];
        return (q.hasVoted[_voter], q.voterChoice[_voter]);
    }
    
    /**
     * @notice Check if an address is a valid MP voter
     * @param _voter The address to check
     * @return isValid True if the address is a valid MP voter
     */
    function isValidMPVoter(address _voter) public view returns (bool isValid) {
        // Check if the voter has at least one MP token
        uint256 balance = mpToken.balanceOf(_voter);
        if (balance == 0) {
            return false;
        }
        
        // Get the total MP count
        uint256 totalMPs = mpTokenFactory.getMPTokenCount();
        
        // Check if the voter owns any active, non-expired MP tokens
        for (uint256 i = 1; i <= totalMPs; i++) {
            try mpToken.ownerOf(i) returns (address owner) {
                if (owner == _voter) {
                    // Check if token is active and not expired
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
    
    /**
     * @notice Get all active questions
     * @return activeQuestionIds Array of active question IDs
     */
    function getActiveQuestions() public view returns (uint256[] memory activeQuestionIds) {
        uint256 activeCount = 0;
        
        // First, count active questions
        for (uint256 i = 1; i <= questionCount; i++) {
            if (questions[i].isActive && 
                questions[i].startTime <= block.timestamp && 
                questions[i].endTime >= block.timestamp) {
                activeCount++;
            }
        }
        
        // Then create array of active question IDs
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
    
    /**
     * @notice Withdraw accumulated vault earnings (emergency function)
     * @dev Only callable by the contract owner in case of stuck funds
     */
    function emergencyWithdraw() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Withdrawal failed");
    }
}
