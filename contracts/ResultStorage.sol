pragma solidity ^0.4.23;

import "./utils/Owned.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IResultStorage.sol";

contract ResultStorage is Owned, IResultStorage {

    event ResultAssigned(uint32 indexed _predictionId, uint8 _outcomeId);

    struct Result {     
        uint8 outcomeId;
        bool resolved; 
    }

    uint8 public constant version = 1;
    bool public paused;
    mapping(uint32 => Result) public results;  

    modifier notPaused() {
        require(paused == false, "Contract is paused");
        _;
    }

    modifier resolved(uint32 _predictionId) {
        require(results[_predictionId].resolved == true, "Prediction is not resolved");
        _;
    }
 
    function setOutcome (uint32 _predictionId, uint8 _outcomeId)
            public 
            onlyOwner
            notPaused {        
        
        results[_predictionId].outcomeId = _outcomeId;
        results[_predictionId].resolved = true;
        
        emit ResultAssigned(_predictionId, _outcomeId);
    }

    function getResult(uint32 _predictionId) 
            public 
            view 
            resolved(_predictionId)
            returns (uint8) {
        return results[_predictionId].outcomeId;
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