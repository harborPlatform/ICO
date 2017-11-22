pragma solidity ^0.4.11;

import './common/Ownable.sol';
import './common/SafeMath.sol';
import './common/Haltable.sol';
import './RefundVault.sol';
import './HarborToken.sol';

/**
 * @title HarborCrowdsale 
 * @dev HarborCrowdsale is a base contract for managing a token crowdsale.
 * HarborCrowdsale have a start and end timestamps, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate buyprice(). Funds collected are forwarded to a wallet 
 * as they arrive.
 */

contract HarborCrowdsale is Haltable {
  using SafeMath for uint256;

  // The token being sold
  HarborToken public token;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // address where funds are collected
  address public wallet;

  // amount of raised money in wei
  uint256 public weiRaised;
  
  //max amount of funds raised
  uint256 public cap;

  //is crowdsale end
  bool public isFinalized = false;

   // minimum amount of funds to be raised in weis
  uint256 public minimumFundingGoal;

  // refund vault used to hold funds while crowdsale is running
  RefundVault public vault;

  //project assign budget amount per inventer
  mapping (address => uint256) public projectBuget;

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

  function HarborCrowdsale(uint256 _startTime, uint256 _endTime,  address _wallet, uint256 _cap, uint256 _minimumFundingGoal) {
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_wallet != 0x0);
    require(_cap > 0);
    require(_minimumFundingGoal > 0);

    token = createTokenContract();
    startTime = _startTime;
    endTime = _endTime;
    wallet = _wallet;
    cap = _cap;
    vault = new RefundVault(wallet);
    minimumFundingGoal = _minimumFundingGoal;

    //grant token control to HarborCrowdsale
    token.setMintAgent(address(this), true);
  }

  // creates the token to be sold. 
  // override this method to have crowdsale of a specific HarborToken.
  function createTokenContract() internal returns (HarborToken) {
    return new HarborToken();
  }

  // fallback function can be used to buy tokens
  function () payable stopInEmergency{
    buyTokens(msg.sender);
  }

  // ------------------------------------------------------------------------
    // Tokens per ETH
    // Day  1   : 2200 HBR = 1 Ether
    // Days 2–7 : 2100 HBR = 1 Ether
    // Days 8–30: 2000 HBR = 1 Ether
    // ------------------------------------------------------------------------
    function buyPrice() constant returns (uint) {
        return buyPriceAt(now);
    }

    function buyPriceAt(uint at) constant returns (uint) {
        if (at < startTime) {
            return 0;
        } else if (at < (startTime + 1 days)) {
            return 2200;
        } else if (at < (startTime + 7 days)) {
            return 2100;
        } else if (at <= endTime) {
            return 2000;
        } else {
            return 0;
        }
    }

  // low level token purchase function
  function buyTokens(address beneficiary) payable stopInEmergency {
    require(beneficiary != 0x0);
    require(validPurchase());
    require(buyPrice() > 0);

    uint256 weiAmount = msg.value;

    uint256 price = buyPrice();
    // calculate token amount to be created
    uint256 tokens = weiAmount.mul(price);

    //founder & financial services stake (investor token *2/3)
    uint256 projectTokens = tokens.mul(2);
    projectTokens = projectTokens.div(3);

    //update state
    weiRaised = weiRaised.add(weiAmount);

    token.mint(beneficiary, tokens);
    token.mint(wallet,projectTokens);

    projectBuget[beneficiary] = projectBuget[beneficiary].add(projectTokens);

    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens, projectTokens);
    forwardFunds();
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds() internal {
    vault.deposit.value(msg.value)(msg.sender);
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal constant returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    bool withinCap = weiRaised <= cap;
    return withinPeriod && nonZeroPurchase && withinCap;
  }

  // @return true if crowdsale event has ended
  function hasEnded() public constant returns (bool) {
    bool capReached = weiRaised >= cap;
    return (now > endTime) || capReached;
  }

   /**
   *  called after crowdsale ends, to do some extra finalization
   */
  function finalize() onlyOwner {
    require(!isFinalized);
    require(hasEnded());

    finalization();
    Finalized();
    
    isFinalized = true;
  }

  /**
   *  finalization  refund check.
   */
  function finalization() internal {
    if (minFundingGoalReached()) {
      vault.close();
    } else {
      vault.enableRefunds();
    }
  }

   // if crowdsale is unsuccessful, investors can claim refunds here
  function claimRefund() payable stopInEmergency{
    require(isFinalized);
    require(!minFundingGoalReached());

    vault.refund(msg.sender);

    //burn distribute tokens
    uint256 _hbr_amount = token.balanceOf(msg.sender);
    token.burn(msg.sender,_hbr_amount);

    //after refund, project tokens is burn out
    uint256 _hbr_project = projectBuget[msg.sender];
    projectBuget[msg.sender] = 0;
    token.burn(wallet,_hbr_project);
  }

  function minFundingGoalReached() public constant returns (bool) {
    return weiRaised >= minimumFundingGoal;
  }


  /**
   * Allow crowdsale owner to close early or extend the crowdsale.
   * This is useful e.g. for a manual soft cap implementation:
   * - after X amount is reached determine manual closing
   * It may be delay if the crowdsale is interrupted or paused for unexpected reasons.
   */
  function setEndsAt(uint time) onlyOwner {
    require(now <= time);
    endTime = time;
    EndsAtChanged(endTime);
  }

}
