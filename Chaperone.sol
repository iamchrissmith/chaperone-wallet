pragma solidity 0.5.8;

import {SafeMath} from "./SafeMath.sol";


contract Chaperone {
    using SafeMath for uint;

    uint public waitingPeriodInSeconds;
    address public chaperone;
    
    mapping (address => uint) pending;
    mapping (address => bool) owners;

    event SubmitOwnerEvent(address indexed newOwner, uint indexed pendingComplete);
    event RejectOwnerEvent(address indexed rejectedOwner, uint indexed rejectedTimestamp);
    event ApproveOwnerEvent(address indexed approvedOwner, uint indexed approvedTimestamp);
    event ExecuteEvent(address indexed owner, address indexed destination, uint indexed value, bytes data);

    modifier isOwner {
        assert(owners[msg.sender] == true);
        _;
    }

    modifier isOwnerOrChaperone {
        assert(owners[msg.sender] == true || chaperone == msg.sender);
        _;
    }

    constructor(address _owner, address _chaperone, uint _waitingPeriodInSeconds) public {
        require(_owner != address(0), "owner-not-zero");
        require(_chaperone != address(0), "chaperone-not-zero");
        require(_waitingPeriodInSeconds != 0, "waiting-period-not-zero");

        owners[_owner] = true;
        chaperone = _chaperone;
        waitingPeriodInSeconds = _waitingPeriodInSeconds;
    }

    function () external payable {}

    function submitOwner(address _pending) public isOwnerOrChaperone {
        require(owners[_pending] == false, "owner-must-be-false");
        require(pending[_pending] == 0, "pending-must-be-zero");

        uint pendingComplete = waitingPeriodInSeconds.add(block.timestamp);
        pending[_pending] = pendingComplete;
        
        emit SubmitOwnerEvent(_pending, pendingComplete);
    }

    function rejectOwner(address _pending) public isOwner {      
        pending[_pending] = 0;
        
        emit RejectOwnerEvent(_pending, block.timestamp);
    }

    function approveOwner(address _pending) public isOwnerOrChaperone {
        require(pending[_pending] != 0, "pending-not-zero");
        require(pending[_pending] < waitingPeriodInSeconds.add(block.timestamp), "waitingPeriod-must-be-passed");
        
        owners[_pending] = true;
        
        emit ApproveOwnerEvent(_pending, block.timestamp);
    }
    
    function execute(address destination, uint value, bytes memory data) public isOwner {
        (bool success, ) = destination.call.value(value)(data);
        require(success, "call-must-succeed");

        emit ExecuteEvent(msg.sender, destination, value, data);
    }
}