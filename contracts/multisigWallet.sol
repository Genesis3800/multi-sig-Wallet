// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MultiSigWallet {

    //Emitted when Eth deposited into contract
    event Deposit(address indexed sender, uint256 amount, uint256 balance);

    //Emitted when transaction submitted to contract, pending approval
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );

    //Emitted when an owner approves a Txn
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);

    //Emitted when an owner revokes their approval on a Txn
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);

    //Emitted when sufficient sigs gathered for a txn to be executed
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    
    address[] public owners;

    //Mapping to check if a given address is an owner or not
    mapping(address => bool) public isOwner;

    //To set how many sigs required for a successful txn. Will be passed as a parameter to constructor
    uint256 public numConfirmationsRequired;

    // Struct for a txn. executed will be set to true when txn carried out.
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    // To see which txns have been approved by which owner
    //Index of 1st txn will be zero
    //Thus, a query of isConfirmed[0] will tell us which owner has approved and which not
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;


    // To let only owners access
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }
    
    //to check if the txn actually exists
    // If index> length, that means the txn array has not
    //even reached that particular index
    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    //Checks bool value 'executed' from the array of structs
    // if executed == false, then allow owner to approve
    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    //Query mapping to check whether
    //That specific txn has been approved by that specific owner    
    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }


     //constructor makes an array of owners, and sets the number of owners required to facilitate a transaction
    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        
        //self-explanatory require conditions
        require(_owners.length > 0, "owners required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length,"invalid number of required confirmations");

        

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            //check for null address
            require(owner != address(0), "invalid owner");
            //check for duplicate owner
            require(!isOwner[owner], "owner not unique");

            //add to isOwner mapping (search mapping above)
            isOwner[owner] = true;

            //push into array of owners.
            owners.push(owner);
        }
        //Update state variable in the end.
        numConfirmationsRequired = _numConfirmationsRequired;
    }

    // To receive Ether into contract
    receive() external payable {
        
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    //To sequentially store txns
    //initially, executed is set to false, 
    //and num of confirms is 0
    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }
    
    //Allows one of the owners to confirm a 
    //specific txn
    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    //to revoke an existing confirmation
    //After checking if a previous confirmation exists
    //this fn will set the bool value of isConfirmed to false
    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx already not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    //returns the total number of approvals for a particular txn
    function getApprovalCount(uint _txIndex) public view returns (uint _count) {

        for(uint i=0; i<owners.length; i++)
        {
            if(isConfirmed[_txIndex][owners[i]])
            _count+=1;
        }
        return _count;
    }

    //if all conditions for approval are met,
    //this function will execute txn.
    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    //returns the array of owners
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    //returns the number of transactions submitted to the contract
    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    //Returns the details of a particular txn
    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
