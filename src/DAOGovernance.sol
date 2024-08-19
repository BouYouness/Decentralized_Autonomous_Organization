// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./DAOToken.sol";
import "./MultiSigWallet.sol";

contract DAOGovernance{

    DAOToken public daoToken;
    MultiSigWallet public multiSigWallet;
    uint256 public proposalCount;

    struct Proposal {
        address proposer;
        string description;
        uint256 withVotes;
        uint256 againstVotes;
        bool executed;
        uint256 endTime;
        bytes transactionData; // Data for transaction if the proposal passes
        uint256 transactionId; // tsx id in the multisigwallet
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description, bytes transactionData);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);

    modifier onlyTokenHolders() {
        require(daoToken.balanceOf(msg.sender) > 0, "should have dao tokens to participate");
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposals[proposalId].proposer != address(0), "this proposal does not exist");
        _;
    }

    modifier notExecuted(uint256 proposalId) {
        require(!proposals[proposalId].executed, "proposal already executed");
        _;
    }

    constructor(address _daoToken , address payable _multiSigWallet) {
        daoToken = DAOToken(_daoToken);
        multiSigWallet = MultiSigWallet(_multiSigWallet);
    }

    function createProposal(string memory _description, bytes memory transactionData) external onlyTokenHolders returns(uint256){
 
        proposalCount++;
        uint256 proposalId = proposalCount;
        proposals[proposalId] = Proposal({
            proposer: msg.sender,
            description:_description,
            withVotes:0,
            againstVotes :0,
            executed:false,
            endTime:block.timestamp + 7 days, // voting period of 7 d
            transactionData:transactionData,
            transactionId:0
        });
        emit ProposalCreated(proposalId, msg.sender, _description, transactionData);

        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external onlyTokenHolders proposalExists(proposalId) notExecuted(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.endTime, "Voting period has ended");
        require(!hasVoted[proposalId][msg.sender], "You have already voted");

        hasVoted[proposalId][msg.sender] = true;

        uint256 voterBalance = daoToken.balanceOf(msg.sender);

        if (support) {
            proposal.withVotes += voterBalance;
        } else {
            proposal.againstVotes += voterBalance;
        }

        emit Voted(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) external proposalExists(proposalId) notExecuted(proposalId){
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.endTime, "Voting period is not yet over");
        require(proposal.withVotes > proposal.againstVotes, "Proposal did not pass");

        proposal.executed = true;

        //Submit the transaction to the MultiSigWallet

        uint256 transactionId = multiSigWallet.submitTransaction(
            address(multiSigWallet), // Execute the transaction via the MultiSigWallet itself
            0, //no eth transfer needed for this governace decision
            proposal.transactionData
        );

        proposal.transactionId = transactionId;

        emit ProposalExecuted(proposalId);

    }

    function getProposal(uint256 proposalId) external view returns(
        address proposer,
        string memory description,
        uint256 withVotes,
        uint256 againstVotes,
        bool executed,
        uint256 endTime,
        uint256 transactionId
    ){
        Proposal storage proposal = proposals[proposalId];
        return(
         proposal.proposer,
            proposal.description,
            proposal.withVotes,
            proposal.againstVotes,
            proposal.executed,
            proposal.endTime,
            proposal.transactionId
        );
    }

    
}