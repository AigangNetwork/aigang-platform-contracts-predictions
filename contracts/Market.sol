pragma solidity ^0.4.23;

import "./utils/OwnedWithExecutor.sol";
import "./utils/SafeMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IResultStorage.sol";
import "./interfaces/IPrizeCalculator.sol";

contract Market is Owned {
    using SafeMath for uint;

    event PredictionAdded(uint32 indexed id);
    event ForecastAdded(uint32 indexed predictionId, uint8 outcomeId, address user); 
    event PredictionStatusChanged(uint32 indexed predictionId, PredictionStatus oldStatus, PredictionStatus newStatus);
    event Refunded(address indexed owner, uint32 indexed predictionId, uint8 outcomeId, uint i, uint refundAmount);
    event PredictionResolved(uint32 indexed predictionId, uint8 winningOutcomeId);
    event PaidOut(uint32 indexed _predictionId, uint8 winningOutcomeId, uint index, address user, uint winAmount);

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
        uint totalTokensNeedForPayout;        
        address resultStorage;   
        address prizeCalculator;
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
        address _resultStorage, address _prizeCalculator) public onlyAllowed notPaused {
        
        predictions[_id].endTime = _endTime;
        predictions[_id].fee = _fee;
        predictions[_id].status = _status;
        predictions[_id].outcomesCount = _outcomesCount;
        predictions[_id].totalTokens = _totalTokens;
        predictions[_id].resultStorage = _resultStorage;
        predictions[_id].prizeCalculator = _prizeCalculator;

        emit PredictionAdded(_id);
    }
    
    // TODO: for testing  1,"0xca35b7d915458ef540ade6068dfe2f44e8fa733c",15,1
    // TODO: reconfigure fallback from AIX token 
    function addForecast(uint32 _predictionId, address _sender, uint _amount, uint8 _outcomeId) 
            public 
            onlyAllowed 
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
            onlyAllowed {
        require(predictions[_predictionId].status != PredictionStatus.NotSet, "Prediction not exist");
        require(_status != PredictionStatus.Resolved, "Use resolve function");
        require(_status != PredictionStatus.Canceled, "Use cancel function");
        emit PredictionStatusChanged(_predictionId, predictions[_predictionId].status, _status);
        predictions[_predictionId].status = _status;            
    }

    function cancel(uint32 _predictionId) public onlyAllowed {    
        emit PredictionStatusChanged(_predictionId, predictions[_predictionId].status, PredictionStatus.Canceled);
        predictions[_predictionId].status = PredictionStatus.Canceled;    
        predictions[_predictionId].totalTokensNeedForPayout = predictions[_predictionId].totalTokens;
    }

    function resolve(uint32 _predictionId) public onlyAllowed {
        require(predictions[_predictionId].status == PredictionStatus.Published, "Prediction must be Published");
        require(predictions[_predictionId].endTime < now, "Prediction is not finished");

        uint8 winningOutcomeId = IResultStorage(predictions[_predictionId].resultStorage).getResult(_predictionId);
        require(winningOutcomeId <= predictions[_predictionId].outcomesCount && winningOutcomeId > 0, "OutcomeId is not valid");

        emit PredictionStatusChanged(_predictionId, predictions[_predictionId].status, PredictionStatus.Resolved);
        predictions[_predictionId].status = PredictionStatus.Resolved;    
        predictions[_predictionId].totalTokensNeedForPayout = predictions[_predictionId].totalTokens;
        
        emit PredictionResolved(_predictionId, winningOutcomeId);
    }

    function payOut(uint32 _predictionId, uint _indexFrom, uint _indexTo) public {
        require(predictions[_predictionId].status == PredictionStatus.Resolved, "Prediction should be resolved");

        uint8 winningOutcomeId = IResultStorage(predictions[_predictionId].resultStorage).getResult(_predictionId);

        require(_indexFrom <= _indexTo && _indexTo < predictions[_predictionId].outcomes[winningOutcomeId].forecasts.length, "Index is not valid");

        //predictions[_predictionId].totalTokens
        IPrizeCalculator calculator = IPrizeCalculator(predictions[_predictionId].prizeCalculator);
        
         for (uint i = _indexFrom; i <= _indexTo; i++) {
            Forecast storage forecast = predictions[_predictionId].outcomes[winningOutcomeId].forecasts[i];

            if (forecast.paidOut == 0) {
                uint winAmount = calculator.calculatePrizeAmount(
                    predictions[_predictionId].totalTokens,
                    predictions[_predictionId].outcomes[winningOutcomeId].totalTokens,
                    forecast.amount
                );
                assert(winAmount > 0);
                assert(IERC20(token).transfer(forecast.user, winAmount));
                forecast.paidOut = winAmount;
                predictions[_predictionId].totalTokensNeedForPayout = predictions[_predictionId].totalTokensNeedForPayout.sub(winAmount);
                emit PaidOut(_predictionId, winningOutcomeId, i, forecast.user, winAmount);
            }
        }          
    }

    // Owner can refund users forecasts
    function refundUser(uint32 _predictionId, uint8 _outcomeId, uint _indexFrom, uint _indexTo) public onlyAllowed {
        require (predictions[_predictionId].status != PredictionStatus.Resolved);
        
        performRefund(_predictionId, _outcomeId, _indexFrom, _indexTo);
    }
   
    // User can refund when status is CANCELED
    function refund(uint32 _predictionId, uint8 _outcomeId, uint _indexFrom, uint _indexTo) public statusIsCanceled(_predictionId) {
        
        performRefund(_predictionId, _outcomeId, _indexFrom, _indexTo);
    }

     function performRefund(uint32 _predictionId, uint8 _outcomeId, uint _indexFrom, uint _indexTo) private {
        require(_indexFrom <= _indexTo && _indexTo < predictions[_predictionId].outcomes[_outcomeId].forecasts.length, "Index is not valid");

        for (uint i = _indexFrom; i <= _indexTo; i++) {
            require(predictions[_predictionId].outcomes[_outcomeId].forecasts[i].paidOut == 0, "Already paid");  

            uint refundAmount = predictions[_predictionId].outcomes[_outcomeId].forecasts[i].amount;
            
            predictions[_predictionId].totalTokensNeedForPayout = predictions[_predictionId].totalTokensNeedForPayout.sub(refundAmount);
            predictions[_predictionId].outcomes[_outcomeId].totalTokens = predictions[_predictionId].outcomes[_outcomeId].totalTokens.sub(refundAmount);
            predictions[_predictionId].outcomes[_outcomeId].forecasts[i].paidOut = refundAmount;
                                                        
            assert(IERC20(token).transfer(predictions[_predictionId].outcomes[_outcomeId].forecasts[i].user, refundAmount)); 
            emit Refunded(predictions[_predictionId].outcomes[_outcomeId].forecasts[i].user, _predictionId, _outcomeId, i, refundAmount);
        }
     }

    //////////
    // View
    //////////
    function getForecast(uint32 _predictionId, uint8 _outcomeId, uint _index) public view returns(address, uint, uint) {
        return (predictions[_predictionId].outcomes[_outcomeId].forecasts[_index].user,
            predictions[_predictionId].outcomes[_outcomeId].forecasts[_index].amount,
            predictions[_predictionId].outcomes[_outcomeId].forecasts[_index].paidOut);
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