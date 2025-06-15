// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MPVoting.sol";
import "../src/MPTokenFactory.sol";
import "../src/MPToken.sol";

contract MPVotingTest is Test {
    MPVoting public votingContract;
    MPTokenFactory public factory;
    MPToken public mpToken;
    
    address public admin = address(0x1);
    address public admin2 = address(0x2);
    address public mp1 = address(0x10);
    address public mp2 = address(0x11);
    address public mp3 = address(0x12);
    address public mp4 = address(0x13);
    address public nonMP = address(0x20);
    address public vault = address(0x30);
    
    uint256 public constant STAKE_AMOUNT = 100 ether;
    uint256 public constant FOUR_YEARS = 4 * 365 days;
    
    event QuestionCreated(uint256 indexed questionId, string question, uint256 startTime, uint256 endTime, address vault);
    event VoteCast(uint256 indexed questionId, address indexed voter, uint256 option, uint256 stake);
    event QuestionClosed(uint256 indexed questionId, uint256 totalVotes, uint256 winningOption);
    event QuestionClosedWithDraw(uint256 indexed questionId, uint256 totalVotes, uint256[] tiedOptions);
    event StakeReturned(uint256 indexed questionId, address indexed voter, uint256 amount);
    event VaultEarnings(uint256 indexed questionId, address indexed vault, uint256 amount);
    
    function setUp() public {
        vm.startPrank(admin);
        factory = new MPTokenFactory();
        mpToken = MPToken(factory.getMPTokenAddress());
        votingContract = new MPVoting(address(factory));
        
        uint256 expirationDate = block.timestamp + FOUR_YEARS;
        factory.createMPToken(mp1, "John Smith", "Conservative", "Westminster North", 2024, expirationDate);
        factory.createMPToken(mp2, "Mary Johnson", "Labour", "Islington South", 2024, expirationDate);
        factory.createMPToken(mp3, "David Williams", "Liberal Democrats", "Birmingham Edgbaston", 2024, expirationDate);
        factory.createMPToken(mp4, "Sarah Brown", "Green Party", "Manchester Central", 2024, expirationDate);
        vm.stopPrank();
        
        vm.deal(mp1, 1000 ether);
        vm.deal(mp2, 1000 ether);
        vm.deal(mp3, 1000 ether);
        vm.deal(mp4, 1000 ether);
        vm.deal(nonMP, 1000 ether);
        vm.deal(vault, 1000 ether);
    }
    
    function testDeployment() public view {
        assertEq(address(votingContract.mpTokenFactory()), address(factory));
        assertEq(address(votingContract.mpToken()), address(mpToken));
        assertTrue(votingContract.hasRole(votingContract.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(votingContract.hasRole(votingContract.ADMIN_ROLE(), admin));
    }
    
    function testConstants() public view {
        assertEq(votingContract.STAKE_AMOUNT(), STAKE_AMOUNT);
        assertEq(votingContract.LOSER_RETURN_PERCENTAGE(), 50);
    }
    
    function testAddAdmin() public {
        vm.startPrank(admin);
        votingContract.addAdmin(admin2);
        assertTrue(votingContract.isAdmin(admin2));
        vm.stopPrank();
    }
    
    function testRemoveAdmin() public {
        vm.startPrank(admin);
        votingContract.addAdmin(admin2);
        votingContract.removeAdmin(admin2);
        assertFalse(votingContract.isAdmin(admin2));
        vm.stopPrank();
    }
    
    function testOnlyAdminCanAddAdmin() public {
        vm.startPrank(nonMP);
        vm.expectRevert("Caller is not an admin");
        votingContract.addAdmin(admin2);
        vm.stopPrank();
    }
    
    function testOnlyAdminCanRemoveAdmin() public {
        vm.startPrank(nonMP);
        vm.expectRevert("Caller is not an admin");
        votingContract.removeAdmin(admin);
        vm.stopPrank();
    }
    
    function testCreateQuestion() public {
        vm.startPrank(admin);
        uint256 startTime = block.timestamp + 1 hours;
        uint256 endTime = startTime + 1 days;
        
        vm.expectEmit(true, false, false, true);
        emit QuestionCreated(1, "Test question?", startTime, endTime, admin);
        
        uint256 questionId = votingContract.createQuestion("Test question?", startTime, endTime);
        
        assertEq(questionId, 1);
        assertEq(votingContract.questionCount(), 1);
        
        (string memory question, string[] memory options, uint256 qStartTime, uint256 qEndTime, 
         bool isActive, uint256 totalVotes, address qVault, uint256 totalStaked, uint256 winningOption) = 
         votingContract.getQuestionDetails(1);
        
        assertEq(question, "Test question?");
        assertEq(options.length, 3);
        assertEq(options[0], "Yes");
        assertEq(options[1], "No");
        assertEq(options[2], "Abstain");
        assertEq(qStartTime, startTime);
        assertEq(qEndTime, endTime);
        assertTrue(isActive);
        assertEq(totalVotes, 0);
        assertEq(qVault, admin);
        assertEq(totalStaked, 0);
        assertEq(winningOption, 0);
        vm.stopPrank();
    }
    
    function testCreateQuestionInvalidTimes() public {
        vm.startPrank(admin);
        
        uint256 futureTime = block.timestamp + 2 hours;
        uint256 earlierTime = block.timestamp + 1 hours;
        
        vm.expectRevert("End time must be after start time");
        votingContract.createQuestion("Test?", futureTime, earlierTime);
        
        vm.expectRevert("Start time must be in the future");
        votingContract.createQuestion("Test?", block.timestamp, futureTime);
        
        vm.stopPrank();
    }
    
    function testOnlyAdminCanCreateQuestion() public {
        vm.startPrank(nonMP);
        vm.expectRevert("Caller is not an admin");
        votingContract.createQuestion("Test?", block.timestamp + 1 hours, block.timestamp + 2 hours);
        vm.stopPrank();
    }
    
    function testUpdateQuestion() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Original?", block.timestamp + 1 hours, block.timestamp + 2 hours);
        
        votingContract.updateQuestion(questionId, "Updated question?");
        
        (string memory question,,,,,,,,) = votingContract.getQuestionDetails(questionId);
        assertEq(question, "Updated question?");
        vm.stopPrank();
    }
    
    function testCannotUpdateAfterVotingStarts() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Test?", block.timestamp + 1 seconds, block.timestamp + 2 hours);
        
        vm.warp(block.timestamp + 2 seconds);
        
        vm.expectRevert("Voting has already started");
        votingContract.updateQuestion(questionId, "Updated?");
        vm.stopPrank();
    }
    
    function testCannotUpdateInvalidQuestion() public {
        vm.startPrank(admin);
        vm.expectRevert("Invalid question ID");
        votingContract.updateQuestion(999, "Updated?");
        vm.stopPrank();
    }
    
    function testIsValidMPVoter() public {
        assertTrue(votingContract.isValidMPVoter(mp1));
        assertTrue(votingContract.isValidMPVoter(mp2));
        assertTrue(votingContract.isValidMPVoter(mp3));
        assertTrue(votingContract.isValidMPVoter(mp4));
        assertFalse(votingContract.isValidMPVoter(nonMP));
    }
    
    function testIsValidMPVoterWithInactiveToken() public {
        vm.startPrank(admin);
        factory.updateMPTokenStatus(1, false);
        vm.stopPrank();
        
        assertFalse(votingContract.isValidMPVoter(mp1));
    }
    
    function testIsValidMPVoterWithExpiredToken() public {
        vm.startPrank(admin);
        uint256 tokenId = factory.createMPToken(nonMP, "Test MP", "Test Party", "Test Constituency", 2024, block.timestamp + 1);
        vm.stopPrank();
        
        assertTrue(votingContract.isValidMPVoter(nonMP));
        
        vm.warp(block.timestamp + 2);
        assertFalse(votingContract.isValidMPVoter(nonMP));
    }
    
    function testVote() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Test question?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2);
        
        vm.startPrank(mp1);
        vm.expectEmit(true, true, false, true);
        emit VoteCast(questionId, mp1, 0, STAKE_AMOUNT);
        
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        (bool hasVoted, uint256 optionIndex) = votingContract.checkVote(questionId, mp1);
        assertTrue(hasVoted);
        assertEq(optionIndex, 0);
        
        assertEq(votingContract.getYesVotesCount(questionId), 1);
        assertEq(votingContract.getNoVotesCount(questionId), 0);
        assertEq(votingContract.getOptionVoteCount(questionId, 0), 1);
        
        (uint256 staked, bool returned, bool canClaim) = votingContract.getStakeInfo(questionId, mp1);
        assertEq(staked, STAKE_AMOUNT);
        assertFalse(returned);
        assertFalse(canClaim);
        
        vm.stopPrank();
    }
    
    function testVoteMultipleVoters() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Test question?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2);
        
        vm.prank(mp1);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp2);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 1);
        
        vm.prank(mp3);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 2);
        
        assertEq(votingContract.getYesVotesCount(questionId), 1);
        assertEq(votingContract.getNoVotesCount(questionId), 1);
        assertEq(votingContract.getOptionVoteCount(questionId, 2), 1);
        
        uint256[] memory allCounts = votingContract.getAllVoteCounts(questionId);
        assertEq(allCounts[0], 1);
        assertEq(allCounts[1], 1);
        assertEq(allCounts[2], 1);
        
        (,,,, bool isActive, uint256 totalVotes,, uint256 totalStaked,) = votingContract.getQuestionDetails(questionId);
        assertEq(totalVotes, 3);
        assertEq(totalStaked, 3 * STAKE_AMOUNT);
    }
    
    function testVoteValidationErrors() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Test question?", block.timestamp + 1 hours, block.timestamp + 2 hours);
        vm.stopPrank();
        
        vm.startPrank(mp1);
        vm.expectRevert("Voting has not started yet");
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 hours + 1);
        
        vm.startPrank(mp1);
        vm.expectRevert("Invalid question ID");
        votingContract.vote{value: STAKE_AMOUNT}(999, 0);
        vm.stopPrank();
        
        vm.startPrank(mp1);
        vm.expectRevert("Invalid option index");
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 5);
        vm.stopPrank();
        
        vm.startPrank(nonMP);
        vm.expectRevert("Not a valid MP voter");
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        vm.stopPrank();
        
        vm.startPrank(mp1);
        vm.expectRevert("Must stake exactly 100 ETH");
        votingContract.vote{value: 50 ether}(questionId, 0);
        vm.stopPrank();
        
        vm.startPrank(mp1);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        vm.stopPrank();
        
        vm.startPrank(mp1);
        vm.expectRevert("Already voted");
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 1);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2 hours);
        vm.startPrank(mp2);
        vm.expectRevert("Voting has ended");
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        vm.stopPrank();
    }
    
    function testCloseQuestion() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Test question?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2);
        
        vm.prank(mp1);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp2);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp3);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 1);
        
        vm.warp(block.timestamp + 1 hours + 1);
        
        vm.startPrank(admin);
        vm.expectEmit(true, false, false, true);
        emit QuestionClosed(questionId, 3, 0);
        
        votingContract.closeQuestion(questionId);
        
        (,,,, bool isActive,,,, uint256 winningOption) = votingContract.getQuestionDetails(questionId);
        assertFalse(isActive);
        assertEq(winningOption, 0);
        
        assertTrue(votingContract.getVotingResults(questionId));
        assertFalse(votingContract.isQuestionDraw(questionId));
        vm.stopPrank();
    }
    
    function testCloseQuestionValidation() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Test question?", block.timestamp + 1, block.timestamp + 1 hours);
        
        vm.expectRevert("Voting period not over yet");
        votingContract.closeQuestion(questionId);
        
        vm.warp(block.timestamp + 1 hours + 1);
        votingContract.closeQuestion(questionId);
        
        vm.expectRevert("Question already inactive");
        votingContract.closeQuestion(questionId);
        
        vm.stopPrank();
    }
    
    function testOnlyAdminCanCloseQuestion() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Test question?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 hours + 1);
        
        vm.startPrank(nonMP);
        vm.expectRevert("Caller is not an admin");
        votingContract.closeQuestion(questionId);
        vm.stopPrank();
    }
    
    function testClaimStakeWinner() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Test question?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2);
        
        uint256 mp1BalanceBefore = mp1.balance;
        
        vm.prank(mp1);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp2);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 1);
        
        uint256 mp1BalanceAfterVote = mp1.balance;
        assertEq(mp1BalanceBefore - mp1BalanceAfterVote, STAKE_AMOUNT);
        
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(admin);
        votingContract.closeQuestion(questionId);
        
        (uint256 staked, bool returned, bool canClaim) = votingContract.getStakeInfo(questionId, mp1);
        assertEq(staked, STAKE_AMOUNT);
        assertFalse(returned);
        assertTrue(canClaim);
        
        vm.startPrank(mp1);
        vm.expectEmit(true, true, false, true);
        emit StakeReturned(questionId, mp1, STAKE_AMOUNT);
        
        votingContract.claimStake(questionId);
        
        uint256 mp1BalanceAfterClaim = mp1.balance;
        assertEq(mp1BalanceAfterClaim, mp1BalanceBefore);
        
        (,bool returnedAfter, bool canClaimAfter) = votingContract.getStakeInfo(questionId, mp1);
        assertTrue(returnedAfter);
        assertFalse(canClaimAfter);
        vm.stopPrank();
    }
    
    function testClaimStakeLoser() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Test question?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2);
        
        uint256 mp1BalanceBefore = mp1.balance;
        uint256 mp2BalanceBefore = mp2.balance;
        uint256 mp3BalanceBefore = mp3.balance;
        uint256 vaultBalanceBefore = admin.balance;
        
        vm.prank(mp1);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp2);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp3);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 1);
        
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(admin);
        votingContract.closeQuestion(questionId);
        
        vm.startPrank(mp3);
        uint256 expectedReturn = (STAKE_AMOUNT * 50) / 100;
        uint256 expectedVaultEarnings = STAKE_AMOUNT - expectedReturn;
        
        vm.expectEmit(true, true, false, true);
        emit VaultEarnings(questionId, admin, expectedVaultEarnings);
        
        vm.expectEmit(true, true, false, true);
        emit StakeReturned(questionId, mp3, expectedReturn);
        
        votingContract.claimStake(questionId);
        
        uint256 mp3BalanceAfterClaim = mp3.balance;
        uint256 vaultBalanceAfterClaim = admin.balance;
        
        assertEq(mp3BalanceBefore - mp3BalanceAfterClaim, STAKE_AMOUNT - expectedReturn);
        assertEq(vaultBalanceAfterClaim - vaultBalanceBefore, expectedVaultEarnings);
        vm.stopPrank();
    }
    
    function testClaimStakeValidation() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Test question?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2);
        
        vm.prank(mp1);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.startPrank(mp1);
        vm.expectRevert("Voting still active");
        votingContract.claimStake(questionId);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(admin);
        votingContract.closeQuestion(questionId);
        
        vm.startPrank(mp2);
        vm.expectRevert("Did not vote on this question");
        votingContract.claimStake(questionId);
        vm.stopPrank();
        
        vm.prank(mp1);
        votingContract.claimStake(questionId);
        
        vm.startPrank(mp1);
        vm.expectRevert("Stake already returned");
        votingContract.claimStake(questionId);
        vm.stopPrank();
        
        vm.startPrank(mp1);
        vm.expectRevert("Invalid question ID");
        votingContract.claimStake(999);
        vm.stopPrank();
    }
    
    function testDrawDetection() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Draw test question?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2);
        
        vm.prank(mp1);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp2);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 1);
        
        vm.warp(block.timestamp + 1 hours + 1);
        
        vm.startPrank(admin);
        uint256[] memory expectedTiedOptions = new uint256[](2);
        expectedTiedOptions[0] = 0;
        expectedTiedOptions[1] = 1;
        
        vm.expectEmit(true, false, false, true);
        emit QuestionClosedWithDraw(questionId, 2, expectedTiedOptions);
        
        votingContract.closeQuestion(questionId);
        
        assertTrue(votingContract.isQuestionDraw(questionId));
        assertFalse(votingContract.getVotingResults(questionId));
        
        uint256[] memory tiedOptions = votingContract.getTiedOptions(questionId);
        assertEq(tiedOptions.length, 2);
        assertEq(tiedOptions[0], 0);
        assertEq(tiedOptions[1], 1);
        
        (,,,, bool isActive,,,, uint256 winningOption) = votingContract.getQuestionDetails(questionId);
        assertFalse(isActive);
        assertEq(winningOption, type(uint256).max);
        
        vm.stopPrank();
    }
    
    function testThreeWayDraw() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Three way draw test?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2);
        
        vm.prank(mp1);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp2);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 1);
        
        vm.prank(mp3);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 2);
        
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(admin);
        votingContract.closeQuestion(questionId);
        
        assertTrue(votingContract.isQuestionDraw(questionId));
        
        uint256[] memory tiedOptions = votingContract.getTiedOptions(questionId);
        assertEq(tiedOptions.length, 3);
        assertEq(tiedOptions[0], 0);
        assertEq(tiedOptions[1], 1);
        assertEq(tiedOptions[2], 2);
        
        (bool isDraw, bool yesWon, bool noWon, uint256 winningOption) = votingContract.getDetailedVotingResults(questionId);
        assertTrue(isDraw);
        assertFalse(yesWon);
        assertFalse(noWon);
        assertEq(winningOption, type(uint256).max);
    }
    
    function testDrawStakeReturns() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Draw stake test?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2);
        
        uint256 mp1BalanceBefore = mp1.balance;
        uint256 mp2BalanceBefore = mp2.balance;
        uint256 vaultBalanceBefore = admin.balance;
        
        vm.prank(mp1);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp2);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 1);
        
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(admin);
        votingContract.closeQuestion(questionId);
        
        assertTrue(votingContract.isQuestionDraw(questionId));
        
        vm.prank(mp1);
        votingContract.claimStake(questionId);
        
        vm.prank(mp2);
        votingContract.claimStake(questionId);
        
        uint256 mp1BalanceAfter = mp1.balance;
        uint256 mp2BalanceAfter = mp2.balance;
        uint256 vaultBalanceAfter = admin.balance;
        
        assertEq(mp1BalanceAfter, mp1BalanceBefore);
        assertEq(mp2BalanceAfter, mp2BalanceBefore);
        assertEq(vaultBalanceAfter, vaultBalanceBefore);
    }
    
    function testGetDetailedVotingResults() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Detailed results test?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2);
        
        vm.prank(mp1);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp2);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp3);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 1);
        
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(admin);
        votingContract.closeQuestion(questionId);
        
        (bool isDraw, bool yesWon, bool noWon, uint256 winningOption) = votingContract.getDetailedVotingResults(questionId);
        
        assertFalse(isDraw);
        assertTrue(yesWon);
        assertFalse(noWon);
        assertEq(winningOption, 0);
    }
    
    function testGetActiveQuestions() public {
        vm.startPrank(admin);
        
        uint256 currentTime = block.timestamp;
        
        uint256 q1 = votingContract.createQuestion("Future question 1?", currentTime + 1 hours, currentTime + 2 hours);
        uint256 q2 = votingContract.createQuestion("Future question 2?", currentTime + 3 hours, currentTime + 4 hours);
        uint256 q3 = votingContract.createQuestion("Future question 3?", currentTime + 5 hours, currentTime + 6 hours);
        uint256 q4 = votingContract.createQuestion("Future question 4?", currentTime + 7 hours, currentTime + 8 hours);
        
        vm.stopPrank();
        
        vm.warp(currentTime + 3 hours + 30 minutes);
        
        uint256[] memory activeQuestions = votingContract.getActiveQuestions();
        
        assertEq(activeQuestions.length, 1);
        assertEq(activeQuestions[0], q2);
        
        vm.warp(currentTime + 7 hours + 30 minutes);
        
        activeQuestions = votingContract.getActiveQuestions();
        
        assertEq(activeQuestions.length, 1);
        assertEq(activeQuestions[0], q4);
    }
    
    function testEmergencyWithdraw() public {
        vm.deal(address(votingContract), 100 ether);
        
        uint256 adminBalanceBefore = admin.balance;
        uint256 contractBalance = address(votingContract).balance;
        
        vm.startPrank(admin);
        votingContract.emergencyWithdraw();
        vm.stopPrank();
        
        assertEq(address(votingContract).balance, 0);
        assertEq(admin.balance, adminBalanceBefore + contractBalance);
    }
    
    function testEmergencyWithdrawNoFunds() public {
        vm.startPrank(admin);
        vm.expectRevert("No funds to withdraw");
        votingContract.emergencyWithdraw();
        vm.stopPrank();
    }
    
    function testOnlyOwnerCanEmergencyWithdraw() public {
        vm.deal(address(votingContract), 100 ether);
        
        vm.startPrank(nonMP);
        vm.expectRevert();
        votingContract.emergencyWithdraw();
        vm.stopPrank();
    }
    
    function testFullVotingCycleWithStaking() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Integration test question?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2);
        
        uint256 vaultBalanceBefore = admin.balance;
        
        vm.prank(mp1);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp2);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp3);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 1);
        
        (,,,,,,, uint256 totalStaked,) = votingContract.getQuestionDetails(questionId);
        assertEq(totalStaked, 3 * STAKE_AMOUNT);
        
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(admin);
        votingContract.closeQuestion(questionId);
        
        assertTrue(votingContract.getVotingResults(questionId));
        assertEq(votingContract.getYesVotesCount(questionId), 2);
        assertEq(votingContract.getNoVotesCount(questionId), 1);
        assertFalse(votingContract.isQuestionDraw(questionId));
        
        vm.prank(mp1);
        votingContract.claimStake(questionId);
        
        vm.prank(mp2);
        votingContract.claimStake(questionId);
        
        vm.prank(mp3);
        votingContract.claimStake(questionId);
        
        uint256 expectedVaultEarnings = STAKE_AMOUNT / 2;
        assertEq(admin.balance - vaultBalanceBefore, expectedVaultEarnings);
        
        (,bool mp1Returned,) = votingContract.getStakeInfo(questionId, mp1);
        (,bool mp2Returned,) = votingContract.getStakeInfo(questionId, mp2);
        (,bool mp3Returned,) = votingContract.getStakeInfo(questionId, mp3);
        
        assertTrue(mp1Returned);
        assertTrue(mp2Returned);
        assertTrue(mp3Returned);
    }
    
    function testReentrancyProtection() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Reentrancy test?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2);
        
        vm.prank(mp1);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(admin);
        votingContract.closeQuestion(questionId);
        
        vm.prank(mp1);
        votingContract.claimStake(questionId);
        
        (,bool returned,) = votingContract.getStakeInfo(questionId, mp1);
        assertTrue(returned);
    }
    
    function testZeroVoteScenario() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("No votes question?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 hours + 1);
        
        vm.prank(admin);
        votingContract.closeQuestion(questionId);
        
        assertEq(votingContract.getYesVotesCount(questionId), 0);
        assertEq(votingContract.getNoVotesCount(questionId), 0);
        assertTrue(votingContract.isQuestionDraw(questionId));
        assertFalse(votingContract.getVotingResults(questionId));
    }
    
    function testTieVoteScenario() public {
        vm.startPrank(admin);
        uint256 questionId = votingContract.createQuestion("Tie question?", block.timestamp + 1, block.timestamp + 1 hours);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2);
        
        vm.prank(mp1);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 0);
        
        vm.prank(mp2);
        votingContract.vote{value: STAKE_AMOUNT}(questionId, 1);
        
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(admin);
        votingContract.closeQuestion(questionId);
        
        assertTrue(votingContract.isQuestionDraw(questionId));
        assertFalse(votingContract.getVotingResults(questionId));
    }
    
    receive() external payable {}
}
