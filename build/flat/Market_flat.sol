pragma solidity ^0.4.13;

interface IMarket {
    function addPrediction() external;
    function addForecast() external;
}

interface IERC20 {
  function transfer(address _to, uint256 _amount) external returns (bool success);
  function transferFrom(address _from, address _to, uint256 _amount) external returns (bool success);
  function balanceOf(address _owner) constant external returns (uint256 balance);
  function approve(address _spender, uint256 _amount) external returns (bool success);
  function allowance(address _owner, address _spender) external constant returns (uint256 remaining);
  function approveAndCall(address _spender, uint256 _amount, bytes _extraData) external returns (bool success);
  function totalSupply() external constant returns (uint);
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

contract Market is Owned {
    event PredictionAdded(uint indexed id);
    event ForecastAdded(uint indexed predictionId, uint8 outcome, address user); 
    event PredictionStatusChange(uint indexed predictionId, PredictionStatus oldStatus, PredictionStatus newStatus);

    using SafeMath for uint;

    uint8 public constant version = 1;
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
        uint endTime;
        uint fee; // in WEIS
        PredictionStatus status;    
        uint8 outcomes;   
        uint totalTokenPool;          
        address oracle;
        Forecast[] forecasts;
    }

    struct Forecast {    
        address user;
        uint amount;
        uint8 outcome;
    }
    
    
    mapping(uint => Prediction) public predictions;
    Forecast[] public forecasts;
    
    function initialize(address _token) external onlyOwner {
        token = _token;
        paused = false;
    }

    modifier notPaused() {
        require(paused == false, "Contract is paused");
        _;
    }

    modifier validPrediction(uint _id, uint _amount, uint8 _outcome) {
        require(predictions[_id].status == PredictionStatus.Published, "Prediction is not published");
        require(predictions[_id].endTime > now, "Prediction is over");
        require(predictions[_id].outcomes >= _outcome, "Outcome is not valid");
        require(_outcome > 0, "Outcome cant be 0");
        require(predictions[_id].fee < _amount, "Amount should be bigger then fee");
        _;
    }
    
    // TODO: for testing 1,2,3,1,6,0,"0xca35b7d915458ef540ade6068dfe2f44e8fa733c" 
    function addPrediction(
        uint _id,
        uint _endTime,
        uint _fee,
        PredictionStatus _status,    
        uint8 _outcomes,  
        uint _totalTokenPool,   
        address _oracle) public onlyOwner notPaused {
        
        predictions[_id].endTime = _endTime;
        predictions[_id].fee = _fee;
        predictions[_id].status = _status;
        predictions[_id].outcomes = _outcomes;
        predictions[_id].totalTokenPool = _totalTokenPool;
        predictions[_id].oracle = _oracle;

        emit PredictionAdded(_id);
    }
    
    // TODO: for testing  1,"0xca35b7d915458ef540ade6068dfe2f44e8fa733c",15,1
    // TODO: reconfigure fallback from AIX token 
    function addForecast(uint _predictionId, address _sender, uint _amount, uint8 _outcome) 
        public 
        onlyOwner 
        notPaused 
        validPrediction(_predictionId, _amount, _outcome) {
            uint amount = _amount.sub(predictions[_predictionId].fee);
            predictions[_predictionId].forecasts.push(Forecast(_sender, amount, _outcome));   
            predictions[_predictionId].totalTokenPool = predictions[_predictionId].totalTokenPool.add(amount);
            emit ForecastAdded(_predictionId, _outcome, _sender);
    }

    function changePredictionStatus(uint _predictionId, PredictionStatus _status) 
        public 
        onlyOwner {
            require(predictions[_predictionId].status != PredictionStatus.NotSet);
            emit PredictionStatusChange(_predictionId, predictions[_predictionId].status, _status);
            predictions[_predictionId].status = _status;            
    }

    //////////
    // Safety Methods
    //////////
    function () public payable {
        require(false);
    }

    function withdrawETH() external onlyOwner {
        owner.transfer(address(this).balance);
    }

    function withdrawTokens(uint _amount, address _token) external onlyOwner {
        IERC20(_token).transfer(owner, _amount);
    }

    function pause(bool _paused) external onlyOwner {
        paused = _paused;
    }

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

