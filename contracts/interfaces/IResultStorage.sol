pragma solidity ^0.4.23;

interface IResultStorage {
    function getResult(uint32 _predictionId) external returns (uint8);
}