pragma solidity ^0.4.13;

contract IMarket {
    function addPrediction() public;
    function addForecast() public;
}

contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

contract Market is Owned, IMarket {
    address public token;
    bool public paused = true;
    
    enum PredictionStatus {
        NotSet,
        Published,
        Resolved,
        Paused,
        Canceled
    }  
    
    struct Prediction {
        uint id;
        address owner;
        uint utcStart;
        uint utcEnd;
        uint fee; // in WEIS
        PredictionStatus status;    
        bytes32[] outcomes;     
       // mapping(bytes32 => OutcomeProperties)  outcomesProperties;
        uint totalTokenPool;          
        address oracle;
    }

    struct Forecast {
        address owner;
        uint amount;
        uint utcPlaced;
        bytes32 outcome;
    }
    
    
    Prediction[] public predictions;
    Forecast[] public forecasts;
    
    function initialize(address _token) external onlyOwner {
        token = _token;
        paused = false;
    }

    modifier notPaused() {
        require(paused == false, "Contract is paused");
        _;
    }
    
    function addPrediction() public onlyOwner notPaused {
        emit PredictionAdded(1);
    }
    
    function addForecast() public onlyOwner notPaused {
        emit ForecastAdded(1, "a");
    }
    
    event PredictionAdded(uint indexed id);
    event ForecastAdded(uint indexed predictionId, bytes32 outcome); 
}

library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}

