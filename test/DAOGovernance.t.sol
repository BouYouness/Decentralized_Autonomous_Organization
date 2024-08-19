    // SPDX-License-Identifier: UNLICENSED
    pragma solidity ^0.8.13;

    import {Test, console} from "forge-std/Test.sol";
    import {DAOToken} from "../src/DAOToken.sol";
    import "../src/MultiSigWallet.sol";
    import "../src/DAOGovernance.sol";

    contract DAOTokenTest is Test {
        DAOToken daoToken;
        MultiSigWallet multiSigWallet;
        DAOGovernance daoGovernance;

        address alice = address(0x123);
        address bob = address(0x456);
        address charlie = address(0x789);

        function setUp() public {
        daoToken = new DAOToken(1000 * 10 ** 18); //deploy a dao token with intial supply of 1000 tokens  

        //Mint tokens to test accounts
        daoToken.mint(alice , 100 *10 ** 18);
        daoToken.mint(bob , 100 *10 ** 18);
        daoToken.mint(charlie, 100 * 10 ** 18);

        // Deploy MultiSigWallet with Alice, Bob, and Charlie as owners, requiring 2 confirmations
        address[3] memory owners;

        owners[0] = alice;
        owners[1] = bob;
        owners[2] = charlie;

        multiSigWallet = new MultiSigWallet(owners ,2);

        // deploy DAOGovernace with the DAO token and MultiSigwallet
        daoGovernance = new DAOGovernance(address(daoToken), payable(address(multiSigWallet)) );

        //approve daogoverance to spend tokens on behalf of the test accounts 
        vm.prank(alice);
        daoToken.approve(address(daoGovernance), 100 * 10**18);

        vm.prank(bob);
        daoToken.approve(address(daoGovernance), 100 * 10**18);

        vm.prank(charlie);
        daoToken.approve(address(daoGovernance), 100 * 10**18);
        }

        function testCreateProposal() public {
            vm.startPrank(alice);
            bytes memory data = abi.encodeWithSignature("someFunction()");
            uint256 proposalId = daoGovernance.createProposal("Proposal 1", data);
            vm.stopPrank();

            (address proposer,string memory description, uint256 withVotes, uint256 againstVotes, bool executed,uint256 endTime ,uint256 transactionId) 
            = daoGovernance.getProposal(proposalId);

            assertEq(description, "Proposal 1");
            //...
            //...
            //...
        }

    function testVoteForProposal() public {
        vm.startPrank(alice);
        bytes memory data = abi.encodeWithSignature("someFunction()");
        uint256 proposalId = daoGovernance.createProposal(" Proposal 1", data);
        vm.stopPrank();

        // Alice votes for the proposal
        vm.prank(alice);
        daoGovernance.vote(proposalId, true);

        (,, uint256 withVotes, uint256 againstVote,,,) = daoGovernance.getProposal(proposalId);
        
        assertEq(withVotes, 100 * 10**18);
        assertEq(againstVote, 0);
    }

    function testExecuteProposal() public {
        // A lice creates a proposal 
        bytes memory data = abi.encodeWithSignature("someFunction()");

        vm.prank(alice);
        uint256 proposalId = daoGovernance.createProposal("Proposal 1", data);

        //Alice and bob vote for the proposal
        vm.prank(alice);
        daoGovernance.vote(proposalId, true);

        vm.prank(bob);
        daoGovernance.vote(proposalId, true);

        vm.warp(block.timestamp + 7 days);

        // Execute the proposal
        vm.prank(alice);
        daoGovernance.executeProposal(proposalId);

        
        (,,,, bool executed,,) = daoGovernance.getProposal(proposalId);
        assertEq(executed, true);
    }

    // Test Edge Cases

    function testCannottVoteWithoutTokens() public {
        // alice gonna create  a proposal
        bytes memory data = abi.encodeWithSignature("someFunction()");
        
        vm.prank(alice);
        uint256 proposalId = daoGovernance.createProposal("Proposal 1", data);

        // charlie gonna transfer all token to bob
        vm.prank(charlie);
        daoToken.transfer(bob, 100 *10 ** 18);

        //then charlie try to vote with zero token 
        vm.startPrank(charlie);
        vm.expectRevert("should have dao tokens to participate");
        //console.log(daoToken.balanceOf(charlie));
        daoGovernance.vote(proposalId, true);
        vm.stopPrank();
    }

    function testCannotVoteAfterEndTime() public {
        // alice gonna create  a proposal
        bytes memory data = abi.encodeWithSignature("someFunction()");
        
        vm.prank(alice);
        uint256 proposalId = daoGovernance.createProposal("Proposal 1", data);

        // forward time to after 7 days
        vm.warp(block.timestamp + 7 days);

        //Alice gonna try to vote
        vm.prank(alice);
        vm.expectRevert("Voting period has ended");
        daoGovernance.vote(proposalId, true);
    }

    function testCannotExecuteFailedProposal() public {
        // alice gonna create  a proposal
        bytes memory data = abi.encodeWithSignature("someFunction()");
        
        vm.prank(alice);
        uint256 proposalId = daoGovernance.createProposal("Proposal 1", data);

        // Bob votes against the proposal 
        vm.prank(bob);
        daoGovernance.vote(proposalId, false);
        
        // forward time to after 7 days
        vm.warp(block.timestamp + 7 days);

        //alice try to execute the proposal 
        vm.prank(alice);
        vm.expectRevert("Proposal did not pass");
        daoGovernance.executeProposal(proposalId);
    }

}
