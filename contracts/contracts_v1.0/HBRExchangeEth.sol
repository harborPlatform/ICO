// pragma solidity ^0.4.11;
pragma solidity ^0.4.24;

import './Ownable.sol';
import '../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol';
import './HBRAssetsEth.sol';
import './HarborToken.sol';
import './HBRIdentification.sol';

/**
 * @title HBRExchangeEth 
 * @dev HBRExchangeEth is a base contract for managing a token tokenExchange.
 * HBRExchangeEth have a start and end timestamps, where investors can make
 * token purchases and the tokenExchange will assign them tokens based
 * on a token per ETH rate exchangePrice(). Funds collected are forwarded to a wallet 
 * as they arrive.
 * This contract has an exchange schedule. However, but if the minimum funds are not reached, 
 * the schedule will be extended automatically.
 * 
 */
contract HBRExchangeEth is Ownable {
  using SafeMath for uint256;

  // The token being sold
  HarborToken public token;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  //project projectBuget and founder stake
  address public projectWallet;
  address public founderWallet;

  // amount of raised funds in wei
  uint256 public weiRaised;
  
  bool public halted;
  //is tokenExchange end
  bool public isFinalized = false;

  // minimum amount of funds to be raised in weis
  uint256 public minimumFundingGoal;

  uint256 public price = 30000;

  // asset Contract used to hold funds for exchange reserves
  HBRAssetsEth public assets;

  //It is possible to deposit only for the address who passed the kyc.
  HBRIdentification whitelist;

  // Funds raised in the start phase
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
    uint256 _startTime, uint256 _endTime,
    address _token, address _assets, 
    address _projectWallet, address _founderWallet,
    uint256 _minimumFundingGoal, address _whitelist
    ) public {

    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_projectWallet != address(0));
    require(_founderWallet != address(0));
    require(_minimumFundingGoal > 0);
    
    startTime = _startTime;
    endTime = _endTime;
    projectWallet = _projectWallet;
    founderWallet = _founderWallet;
    token = HarborToken(_token);
    assets = HBRAssetsEth(_assets);
    whitelist = HBRIdentification(_whitelist);

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

  // fallback function can be used to exchangeTokens
  function () external payable {
    exchangeTokens(msg.sender);
  }


  // ------------------------------------------------------------------------
  // Tokens per ETH
  // UAICO Phase 1        5% Bonus(For 3 days)        21000+1050HBR = 1Ethereum 
  // UAICO Phase 2        3% Bonus(For 12 days)       21000+630HBR = 1Ethereum
  // UAICO Phase 3        0% Bonus(Until end)         21000HBR = 1Ethereum
  // Additional bonuses are provided by the issuer's stake.(Not to make bubbles)
  // ------------------------------------------------------------------------
  function bonusPercent() public constant returns (uint256) {
      return bonusPercentNow(now);
  }

  function bonusPercentNow(uint at) internal constant returns (uint256) {
      if (at < (startTime + 3 days)) {
          return 5;
      } else if (at < (startTime + 12 days)) {
          return 3;
      } else if (at <= endTime) {
          return 0;
      } else {
          return 0;
      }
  }

  //change eth to hbr
  function exchangeTokens(address beneficiary) public payable stopInEmergency {
    require(beneficiary != address(0));
    require(msg.value >= 0);
    require(validPurchase());
    require (whitelist.verify(beneficiary));

    investedETH[beneficiary] = investedETH[beneficiary].add(msg.value);


    uint256 weiAmount = msg.value;

    uint256 percent = bonusPercent();

    uint256 totalMinted = weiAmount.mul(price);

    //Allocation 
    uint256 userToken = (totalMinted.mul(7)).div(10);
    uint256 bonus = (userToken.mul(percent)).div(100);
    userToken = userToken.add(bonus);

    uint256 projectfunds = ((totalMinted.sub(userToken)).mul(666)).div(1000);
    uint256 founderStake = (totalMinted.sub(userToken)).sub(projectfunds);

    //update Eth Total
    weiRaised = weiRaised.add(weiAmount);

    token.mint(beneficiary, userToken);
    token.mint(projectWallet,projectfunds);
    token.mint(founderWallet,founderStake);

    emit TokenPurchase(msg.sender, beneficiary, weiAmount, totalMinted, projectfunds);
    forwardFunds(totalMinted);
  }


  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds(uint256 _mintedAmount) internal {
    assets.deposit.value(msg.value)(msg.sender,_mintedAmount);
  }


  //The exchange is possible until the minimum target amount is reached.
  //Anyone can freely exchange during the exchange period.
  // @return true if the transaction can exchange tokens
  function validPurchase() public constant returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool minimumReached = minFundingGoalReached();

    if(now < startTime){
      return false;
    }

    //Failure to reach minFundingGoal will extend the excange period.
    if(!minimumReached){
      return true;
    }

    return withinPeriod && minimumReached;
  }

  function minFundingGoalReached() public constant returns (bool) {
    return weiRaised >= minimumFundingGoal;
  }

  //Owner can refund the wrong transfered erc20
  function withdrowErc20(address _tokenAddr, address _to, uint _value) public onlyOwner {
    ERC20 erc20 = ERC20(_tokenAddr);
    erc20.transfer(_to, _value);
    emit WithdrowErc20Token(_tokenAddr, _to, _value);
  }

}
