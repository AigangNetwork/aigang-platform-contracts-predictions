pragma solidity ^0.4.13;

interface IERC20 {
  function transfer(address _to, uint256 _amount) external returns (bool success);
  function transferFrom(address _from, address _to, uint256 _amount) external returns (bool success);
  function balanceOf(address _owner) constant external returns (uint256 balance);
  function approve(address _spender, uint256 _amount) external returns (bool success);
  function allowance(address _owner, address _spender) external constant returns (uint256 remaining);
  function approveAndCall(address _spender, uint256 _amount, bytes _extraData) external returns (bool success);
  function totalSupply() external constant returns (uint);
}

interface IResultStorage {
    function getResult(uint32 _predictionId) external returns (uint8);
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
    using SafeMath for uint;

    event PredictionAdded(uint32 indexed id);
    event ForecastAdded(uint32 indexed predictionId, uint8 outcome, address user); 
    event PredictionStatusChanged(uint32 indexed predictionId, PredictionStatus oldStatus, PredictionStatus newStatus);
    event Refunded(address indexed owner, uint32 indexed predictionId, uint8 outcomeId, uint i, uint refundAmount);
    event PredictionResolved(uint32 indexed predictionId, uint8 winningOutcomeId);

    enum PredictionStatus {
        NotSet,    // 0
        Published, // 1
        Resolved,  // 2
        Paused,    // 3
        Canceled   // 4
    }  
    
    struct Prediction {
        uint endTime;
        uint fee; // in WEIS       
        PredictionStatus status;    
        uint8 outcomesCount;
        mapping(uint8 => OutcomesForecasts) outcomes; 
        uint totalTokens;          
        uint totalForecasts;          
        address resultStorage;   
    }

    struct OutcomesForecasts {    
        Forecast[] forecasts;
        uint totalTokens;
    }

    struct Forecast {    
        address user;
        uint amount;
        uint paidOut;
    }

    struct ForecastIndex {    
        uint32 predictionId;
        uint8 outcomeId;
        uint positionIndex;
    }

    uint8 public constant version = 1;
    address public token;
    bool public paused = true;
    mapping(uint32 => Prediction) public predictions;

    mapping(address => ForecastIndex[]) public walletPredictions;
  
    uint public totalFeeCollected;

    modifier notPaused() {
        require(paused == false, "Contract is paused");
        _;
    }

     modifier statusIsCanceled(uint32 _predictionId) {
        require(predictions[_predictionId].status == PredictionStatus.Canceled, "Prediction is not canceled");
        _;
    }

    modifier validPrediction(uint32 _id, uint _amount, uint8 _outcomeId) {
        require(predictions[_id].status == PredictionStatus.Published, "Prediction is not published");
        require(predictions[_id].endTime > now, "Prediction is over");
        require(predictions[_id].outcomesCount >= _outcomeId && _outcomeId > 0, "OutcomeId is not valid");
        require(predictions[_id].fee < _amount, "Amount should be bigger then fee");
        _;
    }
    
    function initialize(address _token) external onlyOwner {
        token = _token;
        paused = false;
    }

    // TODO: for testing 1,1929412716 ,3,1,6,0,"0xca35b7d915458ef540ade6068dfe2f44e8fa733c" 
    function addPrediction(
        uint32 _id,
        uint _endTime,
        uint _fee,
        PredictionStatus _status,    
        uint8 _outcomesCount,  
        uint _totalTokens,   
        address _resultStorage) public onlyOwner notPaused {
        
        predictions[_id].endTime = _endTime;
        predictions[_id].fee = _fee;
        predictions[_id].status = _status;
        predictions[_id].outcomesCount = _outcomesCount;
        predictions[_id].totalTokens = _totalTokens;
        predictions[_id].resultStorage = _resultStorage;

        emit PredictionAdded(_id);
    }
    
    // TODO: for testing  1,"0xca35b7d915458ef540ade6068dfe2f44e8fa733c",15,1
    // TODO: reconfigure fallback from AIX token 
    function addForecast(uint32 _predictionId, address _sender, uint _amount, uint8 _outcomeId) 
            public 
            onlyOwner 
            notPaused 
            validPrediction(_predictionId, _amount, _outcomeId) {

        uint amount = _amount.sub(predictions[_predictionId].fee);
        totalFeeCollected = totalFeeCollected.add(predictions[_predictionId].fee);
   
        predictions[_predictionId].totalTokens = predictions[_predictionId].totalTokens.add(amount);
        predictions[_predictionId].totalForecasts++;
        predictions[_predictionId].outcomes[_outcomeId].totalTokens = predictions[_predictionId].outcomes[_outcomeId].totalTokens.add(_amount);
        predictions[_predictionId].outcomes[_outcomeId].forecasts.push(Forecast(_sender, amount, 0));
       
        walletPredictions[_sender].push(ForecastIndex(_predictionId, _outcomeId, predictions[_predictionId].outcomes[_outcomeId].forecasts.length - 1));

        emit ForecastAdded(_predictionId, _outcomeId, _sender);
    }

    function changePredictionStatus(uint32 _predictionId, PredictionStatus _status) 
            public 
            onlyOwner {
        require(predictions[_predictionId].status != PredictionStatus.NotSet, "Prediction not exist");
        require(_status != PredictionStatus.Resolved, "Use resolve function");
        emit PredictionStatusChanged(_predictionId, predictions[_predictionId].status, _status);
        predictions[_predictionId].status = _status;            
    }

    function resolve(uint32 _predictionId) public onlyOwner {
        require(predictions[_predictionId].status == PredictionStatus.Published, "Prediction must be Published");
        require(predictions[_predictionId].endTime < now, "Prediction is not finished");

        uint8 winningOutcomeId = IResultStorage(predictions[_predictionId].resultStorage).getResult(_predictionId);
        require(winningOutcomeId <= predictions[_predictionId].outcomesCount && winningOutcomeId > 0, "OutcomeId is not valid");

        emit PredictionStatusChanged(_predictionId, predictions[_predictionId].status, PredictionStatus.Resolved);
        predictions[_predictionId].status = PredictionStatus.Resolved;      
        
        emit PredictionResolved(_predictionId, winningOutcomeId);
    }

    function payOut(uint32 _predictionId, uint indexFrom, uint indexTo) public {
        require(predictions[_predictionId].status == PredictionStatus.Resolved, "Prediction should be resolved");

        uint8 winningOutcomeId = IResultStorage(predictions[_predictionId].resultStorage).getResult(_predictionId);

        require(indexFrom <= indexTo && indexTo < predictions[_predictionId].outcomes[winningOutcomeId].forecasts.length, "Index is not valid");

        //predictions[_predictionId].totalTokens
        
        // for (uint i = indexFrom; i <= indexTo; i++) {
        //     Forecast f = predictions[_predictionId].outcomes[winningOutcomeId].forecasts[i];

        //     if (f.paidOut == 0) {

        //     } else {
        //         f.paidOut
        //     }

        // }   

       
    }

    function getForecast(uint32 _predictionId, uint8 _outcomeId, uint _index) public view returns(address, uint, uint) {
        return (predictions[_predictionId].outcomes[_outcomeId].forecasts[_index].user,
            predictions[_predictionId].outcomes[_outcomeId].forecasts[_index].amount,
            predictions[_predictionId].outcomes[_outcomeId].forecasts[_index].paidOut);
    }

    //////////
    // Refund
    //////////
    // Owner can refund users forecasts
    function refundUser(address _user, uint32 _predictionId, uint8 _outcomeId, uint _index) public onlyOwner {
        require (predictions[_predictionId].status != PredictionStatus.Resolved);
        
        performRefund(_user,  _predictionId, _outcomeId, _index);
    }
   
    // User can refund when status is CANCELED
    function getRefund(uint32 _predictionId, uint8 _outcomeId) public statusIsCanceled(_predictionId) {
               
        searchRefund(msg.sender,  _predictionId, _outcomeId);
    }
   
    function searchRefund(address _owner, uint32 _predictionId, uint8 _outcomeId) private {
        require(predictions[_predictionId].totalTokens > 0, "Prediction token pool is empty");
        require(walletPredictions[_owner].length > 0, "User dont have forecasts");

        uint i;

        for (i = 0; i < walletPredictions[_owner].length; i++) {
            if (walletPredictions[_owner][i].predictionId == _predictionId 
                    && walletPredictions[_owner][i].outcomeId == _outcomeId
                    && predictions[_predictionId].outcomes[_outcomeId].forecasts[walletPredictions[_owner][i].positionIndex].paidOut == 0) {
                i = walletPredictions[_owner][i].positionIndex;
                break;
            }
        }

        performRefund(_owner, _predictionId, _outcomeId, i);        
    }

     function performRefund(address _owner, uint32 _predictionId, uint8 _outcomeId, uint _index) private {
        require(predictions[_predictionId].outcomes[_outcomeId].forecasts[_index].paidOut == 0, "Already paid");  

        uint refundAmount = predictions[_predictionId].outcomes[_outcomeId].forecasts[_index].amount;
        
        predictions[_predictionId].totalTokens = predictions[_predictionId].totalTokens.sub(refundAmount);
        predictions[_predictionId].outcomes[_outcomeId].totalTokens = predictions[_predictionId].outcomes[_outcomeId].totalTokens.sub(refundAmount);
        predictions[_predictionId].outcomes[_outcomeId].forecasts[_index].paidOut = refundAmount;
                                                       
        assert(IERC20(token).transfer(_owner, refundAmount)); 
        emit Refunded(_owner, _predictionId, _outcomeId, _index, refundAmount);
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

