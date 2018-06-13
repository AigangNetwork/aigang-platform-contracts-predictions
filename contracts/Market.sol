pragma solidity ^0.4.23;

import "./utils/Owned.sol";
import "./utils/SafeMath.sol";

contract IMarket {
    function addPrediction() public;
    function addForecast() public;
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