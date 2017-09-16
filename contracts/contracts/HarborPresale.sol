pragma solidity ^0.4.11;

import './common/SafeMath.sol';
import './common/Ownable.sol';
import './common/Haltable.sol';
import './RefundVault.sol';
import './HarborToken.sol';

/**
 * @title HarborPresale 
 */
contract HarborPresale is Haltable {
  using SafeMath for uint256;

  // The token being sold
  HarborToken public token;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // address where funds are excutionFunds
  address public wallet;

  // how many token units a buyer gets per wei
  uint256 public rate;

  // amount of raised money in wei
  uint256 public weiRaised;
  
  //max amount of funds raised
  uint256 public cap;

  //is crowdsale end
  bool public isFinalized = false;

   // minimum amount of funds to be raised in weis
  uint256 public minimumFundingGoal;

  // minimum amount of funds for once 
  uint256 public minSend;

  // refund vault used to hold funds while crowdsale is running
  RefundVault public vault;


  //How many tokens were Minted
  uint public tokensMinted;
  //presale buyers
  mapping (address => uint256) public tokenDeposited;

  //event for crowdsale end
  event Finalized();

 //event for presale mint
  event TokenMinted(uint count);

  // We distributed tokens to an investor
  event Distributed(address investor, uint tokenAmount);

  //presale period is Changed
  event PeriodChanged(uint256 starttm,uint256 endtm);


  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param investor who participate presale
   * @param value weis paid for purchase
   */ 
  event TokenPurchase(address indexed purchaser, address indexed investor, uint256 value);

  function HarborPresale(address _token, uint256 _startTime, uint256 _endTime, uint256 _rate, address _wallet, uint256 _cap, uint256 _minimumFundingGoal, uint256 _minSend) {
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_rate > 0);
    require(_wallet != 0x0);
    require(_cap > 0);
    require(_minimumFundingGoal > 0);
    
    token = HarborToken(_token);
    startTime = _startTime;
    endTime = _endTime;
    rate = _rate;
    wallet = _wallet;
    cap = _cap;
    vault = new RefundVault(_wallet);
    minimumFundingGoal = _minimumFundingGoal;
    minSend = _minSend;
  }

  // fallback function can be used to buy tokens
  function () payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address investor) payable stopInEmergency {
    require(investor != 0x0);
    require(validPurchase());
    require(minSend <= msg.value);

    uint256 weiAmount = msg.value;
    
    // update state
    weiRaised = weiRaised.add(weiAmount);

    //save for distribution HBR
    tokenDeposited[investor] = tokenDeposited[investor].add(weiAmount);

    //valut save for refund
    vault.deposit.value(msg.value)(msg.sender);

    TokenPurchase(msg.sender, investor, weiAmount);
  }

  /**
   * Load funds to the crowdsale for all investors.
   */
  function mintForEverybody() onlyOwner public {

    uint256 allTokenAmount = weiRaised.mul(rate);
    //for project amount (investor token *2/3)
    uint256 projectAmount = allTokenAmount.mul(2);
    projectAmount = projectAmount.div(3);
    //mint for investor;
    token.mint(address(this),allTokenAmount);
    //mint for project share
    token.mint(wallet,projectAmount);

    // Record how many tokens we got
    tokensMinted = allTokenAmount.add(projectAmount);

    TokenMinted(tokensMinted);
  }

  //get claim of token byself
  function claimToken() payable stopInEmergency{
    claimTokenAddress(msg.sender);
  }

  //get claim of token by address
  function claimTokenAddress(address investor) payable stopInEmergency returns(uint256){
     require(isFinalized);
     require(tokenDeposited[investor] != 0);
    
    uint256 depositedValue = tokenDeposited[investor];
    tokenDeposited[investor] = 0;

    uint256 tokenAmount = depositedValue * rate;
    //send token to investor
    token.transfer(investor,tokenAmount);
    Distributed(investor, tokenAmount);
    return tokenAmount;
  }


  // @return true if the transaction can buy tokens
  function validPurchase() internal constant returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    bool withinCap = weiRaised <= cap;
    return withinPeriod && nonZeroPurchase && withinCap;
  }

  // @return true if HarborPresale event has ended
  function hasEnded() public constant returns (bool) {
    bool capReached = weiRaised >= cap;
    return (now > endTime) || capReached ;
  }

   /**
   *  called after Presale ends
   */
  function finalize() onlyOwner stopInEmergency{
    require(!isFinalized);
    require(hasEnded());

    finalization();
    Finalized();
    
    isFinalized = true;
  }

  /**
   *  finalization  refund or excute funds.
   */
  function finalization() internal {
    if (minFundingGoalReached()) {
      vault.close();
    } else {
      vault.enableRefunds();
    }
  }

   // if presale is unsuccessful, investors can claim refunds here
  function claimRefund() stopInEmergency payable {
    require(isFinalized);
    require(!minFundingGoalReached());
    vault.refund(msg.sender);
  }

  function minFundingGoalReached() public constant returns (bool) {
    return weiRaised >= minimumFundingGoal;
  }

  //change presale preiod 
  function setPeriod(uint256 _startTime,uint256 _endTime) onlyOwner {
    require(now <= _endTime);
    startTime = _startTime;
    endTime = _endTime;
    PeriodChanged(startTime,endTime);
  }
  
  //withdrow for manual distribution
  function withdrawFund() onlyOwner payable{
    require(isFinalized);
    require(minFundingGoalReached());
    uint256 tokenAmount = token.balanceOf(address(this));
    token.transfer(wallet, tokenAmount);
  }

}