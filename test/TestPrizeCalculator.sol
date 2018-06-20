pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/PrizeCalculator.sol";
import "../contracts/utils/SafeMath.sol";

contract TestPrizeCalculator {
   function test_ping() public {
        Assert.equal(true, true, "Ping");
   }

  function test_happyflow() public {
    IPrizeCalculator c = new PrizeCalculator();

    uint result = c.calculatePrizeAmount(5000, 200, 10);

    Assert.equal(result, 250, "Prize should be 250");
  }

  function test_happyflow_ether() public {
    IPrizeCalculator c = new PrizeCalculator();

    uint result = c.calculatePrizeAmount(5000 ether, 200 ether, 10 ether);
    Assert.equal(result, 250 ether, "Prize should be 250");

    result = c.calculatePrizeAmount(99999 ether, 99999 ether, 99999 ether);
    Assert.equal(result, 99999 ether, "Prize should be 99999");
  }

//   function test_revert() {
//     PrizeCalculator c = new PrizeCalculator();
//     ThrowProxy throwProxy = new ThrowProxy(address(c));

//     //prime the proxy.
//     PrizeCalculator(address(throwProxy)).calculatePrizeAmount(0, 0, 0);

//     //execute the call that is supposed to throw.
//     //r will be false if it threw. r will be true if it didn't.
//     //make sure you send enough gas for your contract method.
   
//     bool r = throwProxy.execute.gas(200000)();
//     Assert.isFalse(r, "Should be false, as it should throw");


//     //Assert.equal(result, 250, "Prize should be 250");
//   }

// Proxy contract for testing throws
// contract ThrowProxy {
//   address public target;
//   bytes data;

//   function ThrowProxy(address _target) {
//     target = _target;
//   }

//   //prime the data using the fallback function.
//   function() {
//     data = msg.data;
//   }

//   function execute() returns (bool) {
//     return target.call(data);
//   }
// }
}