pragma solidity ^0.4.11;

import '../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol';
import '../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol';
import './HBRAssetsEth.sol';
import './HarborToken.sol';
import './HBRIdentification.sol';

/**
 * @title HBRExchangeEth 
 * @dev HBRExchangeEth is a base contract for managing a token crowdsale.
 * HBRExchangeEth have a start and end timestamps, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate buyprice(). Funds collected are forwarded to a wallet 
 * as they arrive.
 */

contract HBRExchangeEth is Ownable{
  using SafeMath for uint256;

  // The token being sold
  HarborToken public token;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // address where funds are collected
  address public projectWallet;
  address public founderWallet;

  // amount of raised money in wei
  uint256 public weiRaised;
  
  bool public halted;
  //is crowdsale end
  bool public isFinalized = false;

  // minimum amount of funds to be raised in weis
  uint256 public minimumFundingGoal;


  uint256 public price = 25000;

  uint256 public limitKycAml;

  HBRIdentification kycAmlChecker;

  // asset Contract used to hold funds for exchange reserves
  HBRAssetsEth public assets;

  //project assign budget amount per inventer
  // mapping (address => uint256) public projectBuget;
  mapping (address => uint256) public investedETH;

  //event for crowdsale end
  event Finalized();

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */ 
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount,uint256 projectamount);

    // Crowdsale end time has been changed
  event EndsAtChanged(uint newEndsAt);

  function HBRExchangeEth(uint256 _price,uint256 _startTime, uint256 _endTime,
    address _token ,address _assets,  address _kycAml, address _projectWallet,address _founderWallet,
    uint256 _minimumFundingGoal, uint256 _limitKycAml) {
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_projectWallet != 0x0);
    require(_founderWallet != 0x0);
    require(_minimumFundingGoal > 0);
    require(_limitKycAml > 0);

    price = _price;
    startTime = _startTime;
    endTime = _endTime;
    projectWallet = _projectWallet;
    founderWallet = _founderWallet;
    token = HarborToken(_token);
    assets = HBRAssetsEth(_assets);
    kycAmlChecker = HBRIdentification(_kycAml);
    minimumFundingGoal = _minimumFundingGoal;
    limitKycAml = _limitKycAml;

    //grant token control to HBRExchangeEth
    // token.setMintAgent(address(this), true);
  }

  function reset(uint256 _price,uint256 _startTime, uint256 _endTime,
    address _projectWallet,address _founderWallet,
    uint256 _minimumFundingGoal) onlyOwner {
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_projectWallet != 0x0);
    require(_founderWallet != 0x0);
    require(_minimumFundingGoal > 0);

    price = _price;
    startTime = _startTime;
    endTime = _endTime;
    projectWallet = _projectWallet;
    founderWallet = _founderWallet;
    minimumFundingGoal = _minimumFundingGoal;
  }

  modifier stopInEmergency {
    require(!halted);
    _;
  }

  // called by the owner on emergency, triggers stopped state
  function halt() external onlyOwner {
    halted = true;
  }

  // called by the owner on end of emergency, returns to normal state
  function unhalt() external onlyOwner  {
    require(halted);
    halted = false;
  }

  // fallback function can be used to buy tokens
  function () payable{
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) payable stopInEmergency {
    require(beneficiary != 0x0);
    require(validPurchase());

     // If the amount is over limitKycAml, check for user verification for KYC & AML.
    if(limitKycAml < investedETH[beneficiary].add(msg.value)){
      if(kycAmlChecker.verify(beneficiary) == false){
        revert();
      }
    }

    investedETH[beneficiary] = investedETH[beneficiary].add(msg.value);

    //비율 조절 필요
    uint256 weiAmount = msg.value;

    // calculate token amount to be created
    uint256 totalMinted = weiAmount.mul(price);

    //founder skake (10%) & project funds stake (20%) (investor token's  30%)
    uint256 projectfunds = totalMinted.div(5);
    uint256 founderSkake = totalMinted.div(10);
    uint256 userToken = totalMinted.sub(projectfunds).sub(founderSkake);

    //update Eth Total
    weiRaised = weiRaised.add(weiAmount);

    token.mint(beneficiary, userToken);
    token.mint(projectWallet,projectfunds);
    token.mint(founderWallet,founderSkake);

    TokenPurchase(msg.sender, beneficiary, weiAmount, totalMinted, projectfunds);
    forwardFunds(totalMinted);
  }

  function validation() public returns(bytes32){
    bool withinPeriod = now >= startTime && now <= endTime;
     if(withinPeriod == false){
      return 'withinPeriod fail';
     }

     address beneficiary = msg.sender;
     if(limitKycAml < investedETH[beneficiary].add(msg.value)){
      if(kycAmlChecker.verify(beneficiary) == false){
        return 'fail kyc';
      }
    }
    return 'ok';
  }


  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds(uint256 _mintedAmount) internal {
    bool result = assets.deposit.value(msg.value)(msg.sender,_mintedAmount);
    if(result == false){
      revert();
    }
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal constant returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    bool minimumReached = minFundingGoalReached();

    if(minimumReached == false){
      return nonZeroPurchase && now >= startTime;
    }
    return withinPeriod && nonZeroPurchase;
  }

  function minFundingGoalReached() public constant returns (bool) {
    return weiRaised >= minimumFundingGoal;
  }

}
