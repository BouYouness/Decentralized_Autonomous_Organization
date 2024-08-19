// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract MultiSigWallet {
    address[] public owners;
    uint256 public required;
    uint256 public transactionCount;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    mapping(address => bool) public isOwner;
    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    event Deposit(address indexed sender, uint256 value);
    event SumbitTransaction(uint256 indexed transactionId, address indexed to, uint256 value, bytes data);
    event ConfirmTransaction(address indexed owner, uint256 indexed transactionId);
    event ExecuteTransaction(uint256 indexed transactionId);
    event RevokeConfirmation(address indexed owner, uint256 indexed transactionId);


    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier transactionExists(uint256 transactionId){
        require(transactions[transactionId].to != address(0), "Transaction does not exist");
        _;
    }

    modifier notConfirmed(uint256 transactionId, address owner){
       require(!transactions[transactionId].executed, "Transaction already executed");
        _; 
    }

    modifier confirmed(uint256 transactionId, address owner) {
        require(confirmations[transactionId][owner], "Transaction not confirmed");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "Transaction already executed");
        _;
    }

    constructor(address[3] memory _owners, uint256 _required){
        require(_owners.length > 0 , "owners required");
        require(_required > 0 && _required < _owners.length, "Invalid number of required confirmations");

        for (uint256 i = 0; i < _owners.length; i++){
          address owner = _owners[i];
          require(owner != address(0), "Invalid owner");
          isOwner[owner] = true;
          owners.push(owner);
        }

      required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address to, uint256 value, bytes memory data) public /*onlyOwner*/ returns(uint256){
        transactionCount++;

        uint256 transactionId = transactionCount ;
        transactions[transactionId] = Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 0   
        });
        emit SumbitTransaction(transactionId, to, value , data);

        return transactionId; 
    }

    function confirmTransaction(uint256 transactionId) 
        public 
        onlyOwner 
        transactionExists(transactionId) 
        notConfirmed(transactionId, msg.sender) 
    {
        confirmations[transactionId][msg.sender] = true;
        transactions[transactionId].confirmations++;

        emit ConfirmTransaction(msg.sender, transactionId);

        if (transactions[transactionId].confirmations >= required) {
            executeTransaction(transactionId);
        }
    }

    function executeTransaction(uint256 transactionId)
    public
    onlyOwner
    transactionExists(transactionId) 
    notExecuted(transactionId) 
    {
      Transaction storage txn = transactions[transactionId];

      require(txn.confirmations >= required , "not enough confirmations");

      txn.executed = true;

      (bool success,) = txn.to.call{value: txn.value}(txn.data);
      require(success, "txn failed");

      emit ExecuteTransaction(transactionId);
    }

    function revokeConfirmation(uint256 transactionId) 
        public 
        onlyOwner 
        transactionExists(transactionId) 
        confirmed(transactionId, msg.sender) 
        notExecuted(transactionId) 
    {
        confirmations[transactionId][msg.sender] = false;
        transactions[transactionId].confirmations--;

        emit RevokeConfirmation(msg.sender, transactionId);
    }

    function getTransaction(uint256 transactionId)
    public
    view
    returns (
        address to,
        uint256 value,
        bytes memory data,
        bool executed,
        uint256 confirmations
    ){
        Transaction storage txn = transactions[transactionId];
         return (txn.to, txn.value, txn.data, txn.executed, txn.confirmations);
    }
    
    function isConfirmed(uint256 transactionId) public view returns (bool) {
        return transactions[transactionId].confirmations >= required;
    }


}