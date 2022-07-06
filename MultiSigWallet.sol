// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1 < 0.9;
contract MultiSignatureWallet {
    event Deposit(address indexed sender, uint amount, uint balance);
    event Submit(
        address indexed owner,
        uint indexed txnIndex,
        address indexed to,
        uint value,
        bytes data
    );
    event Confirm(address indexed owner, uint indexed txnIndex);
    event Revoke(address indexed owner, uint indexed txnIndex);
    event Execute(address indexed owner, uint indexed txnIndex);
    address[] public owners;
    mapping(address => bool) public isOwner;
    mapping(uint => mapping(address => bool)) public isConfirmed;
    uint public requiredConfirmation;
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numberOfConfirmations;
    }
    Transaction[] public transactions;
    modifier onlyOwners() {
        require(isOwner[msg.sender], "You're not an owner");
        _;
    }
    modifier TXNExists(uint _txnIndex) {
        require(_txnIndex < transactions.length, "Transaction does not exist");
        _;
    }
    modifier txnNotExecuted(uint _txnIndex) {
        require(!transactions[_txnIndex].executed, "Transactional is ready executed");
        _;
    }
    modifier txnNotConfirmed(uint _txnIndex) {
        require(!isConfirmed[_txnIndex][msg.sender], "Transaction already confirmed");
        _;
    }
    constructor(address[] memory _owners) {
        require(_owners.length > 0, "Owners required");
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner is not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }
        requiredConfirmation = _owners.length;
    }
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
    function SubmitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwners {
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numberOfConfirmations: 0
            })
        );
        emit Submit(msg.sender, transactions.length, _to, _value, _data);
    }
    function ConfirmTransaction(uint _txnIndex)
        public
        onlyOwners
        TXNExists(_txnIndex)
        txnNotExecuted(_txnIndex)
        txnNotConfirmed(_txnIndex)
    {
        Transaction storage transaction = transactions[_txnIndex];
        transaction.numberOfConfirmations += 1;
        isConfirmed[_txnIndex][msg.sender] = true;
        emit Confirm(msg.sender, _txnIndex);
    }
    function ExecuteTransaction(uint _txnIndex)
        public
        onlyOwners
        TXNExists(_txnIndex)
        txnNotExecuted(_txnIndex)
    {
        Transaction storage transaction = transactions[_txnIndex];
        require( transaction.numberOfConfirmations >= requiredConfirmation, "Transaction cannot be executed" );
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Transaction failed");
        emit Execute(msg.sender, _txnIndex);
    }
    function RevokeTransaction(uint _txnIndex)
        public
        onlyOwners
        TXNExists(_txnIndex)
        txnNotExecuted(_txnIndex)
    {
        Transaction storage transaction = transactions[_txnIndex];
        require(isConfirmed[_txnIndex][msg.sender], "Transaction is not confirmed");
        transaction.numberOfConfirmations -= 1;
        isConfirmed[_txnIndex][msg.sender] = false;
        emit Revoke(msg.sender, _txnIndex);
    }
    function getOwners() public view returns (address[] memory) {
        return owners;
    }
    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }
    function getTransaction(uint _txnIndex)
        public
        view
        returns ( address to, uint value, bytes memory data, bool executed, uint numberOfConfirmations )
    {
        return (
            transactions[_txnIndex].to,
            transactions[_txnIndex].value,
            transactions[_txnIndex].data,
            transactions[_txnIndex].executed,
            transactions[_txnIndex].numberOfConfirmations
        );
    }
}
