// pragma solidity ^0.4.11;
pragma solidity ^0.4.24;

import './Ownable.sol';
import '../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol';
import './HBRAssetsEth.sol';
import './HarborToken.sol';
// import './HBRIdentification.sol';

/**
 * @title HBRExchangeEth 
 * @dev HBRExchangeEth is a base contract for managing a token tokenExchange.
 * HBRExchangeEth have a start and end timestamps, where investors can make
 * token purchases and the tokenExchange will assign them tokens based
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
  //is tokenExchange end
  bool public isFinalized = false;

  // minimum amount of funds to be raised in weis
  uint256 public minimumFundingGoal;


  uint256 public price = 25000;

  // asset Contract used to hold funds for exchange reserves
  HBRAssetsEth public assets;

  //project assign budget amount per inventer
  // mapping (address => uint256) public projectBuget;
  mapping (address => uint256) public investedETH;

  
  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */ 
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount,uint256 projectamount);
  event EndsAtChanged(uint newEndsAt);
  event WithdrowErc20Token (address indexed erc20, address indexed wallet, uint value);
  event Finalized();

  constructor(
    uint256 _price,uint256 _startTime, uint256 _endTime,
    address _token, address _assets, 
    address _projectWallet, address _founderWallet,
    uint256 _minimumFundingGoal
    ) public {

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
    token = HarborToken(_token);
    assets = HBRAssetsEth(_assets);
    minimumFundingGoal = _minimumFundingGoal;
    

    //grant token control to HBRExchangeEth
    //token.setMintAgent(address(this), true);
  }

  function reset(
    uint256 _price, uint256 _startTime, uint256 _endTime,
    address _projectWallet, address _founderWallet,
    uint256 _minimumFundingGoal
    ) public onlyOwner {
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
  function () external payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) public payable stopInEmergency {
    require(beneficiary != 0x0);
    require(msg.value >= 0);
    require(validPurchase());

    investedETH[beneficiary] = investedETH[beneficiary].add(msg.value);

    //비율 조절 필요
    uint256 weiAmount = msg.value;

    // calculate token amount to be created
    uint256 totalMinted = weiAmount.mul(price);

    uint256 userToken = totalMinted.mul(7).div(100);
    uint256 bonus = userToken.mul(5).div(100);
    userToken = userToken.add(bonus);

    uint256 projectfunds = (totalMinted.sub(userToken)).mul(6).div(100);
    uint256 founderStake = (totalMinted.sub(userToken)).sub(projectfunds);

    //founder skake (10%) & project funds stake (20%) = (investor token's  30%)
    // uint256 projectfunds = totalMinted.div(5);
    // uint256 founderStake = totalMinted.div(10);
    // uint256 userToken = totalMinted.sub(projectfunds).sub(founderStake);

    //update Eth Total
    weiRaised = weiRaised.add(weiAmount);

    token.mint(beneficiary, userToken);
    token.mint(projectWallet,projectfunds);
    token.mint(founderWallet,founderStake);

    emit TokenPurchase(msg.sender, beneficiary, weiAmount, totalMinted, projectfunds);
    forwardFunds(totalMinted);
  }

  function validation() public view returns(bool){
    bool withinPeriod = now >= startTime && now <= endTime;
     if(withinPeriod == false){
      return false;
     }
    return true;
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
    bool minimumReached = minFundingGoalReached();

    if(now < startTime){
      return false;
    }

    return withinPeriod && minimumReached;
  }

  function minFundingGoalReached() public constant returns (bool) {
    return weiRaised >= minimumFundingGoal;
  }

  function withdrowErc20(address _tokenAddr, address _to, uint _value) public onlyOwner {
    ERC20 erc20 = ERC20(_tokenAddr);
    erc20.transfer(_to, _value);
    emit WithdrowErc20Token(_tokenAddr, _to, _value);
  }

}
