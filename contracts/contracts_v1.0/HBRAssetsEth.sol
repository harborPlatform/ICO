pragma solidity ^0.4.11;

import '../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol';
import './Authorized.sol';
import './PolicyManager.sol';
import './HarborToken.sol';
import './HBRFrozenAssets.sol';

/**
 * @title HBRAssetsEth
 * @dev This contract is used for storing funds 
 * Supports Withdrawal the money if anytimes  
 *  However, it differs from the rate that was exchanged at the time of payment.
 */
contract HBRAssetsEth is Authorized {
  using SafeMath for uint256;

  enum State { StopAll, ActiveAll, OnlyDeposit ,OnlyWithdrawl }

  struct Receipt {
        uint regDate;
        uint amount;
    }

  mapping (address => uint256) public accounts;

  HarborToken public token;
  HBRFrozenAssets public frozonAssets;
  //reservation to withdrawal;
  mapping (address => Receipt) public reservation;

  //After reservation need to watit 'minuteWating' time
  uint public minuteWating;
  //After withdrawable have to withdrawal until noShowLimit
  uint public noShowLimit;
  


  //asset state
  State public state;
  //ETH reserves for refunds (fundamental asset)
  uint public ethTotal;
  //HBR issuance corresponding to deposited ETH 
  uint public hbrTotal;

  bool public equalizeLevel;

  event StateChanged();
  event Deposit(address indexed addr,uint256 eth_amount,uint256 hbr_amount);
  event Withdrawn(address indexed addr, uint256 weiAmount);
  event Burn(address indexed addr, uint256 amount, bytes32 info);

  function HBRAssetsEth(address _tokenAddr) {
    state = State.ActiveAll;
    token = HarborToken(_tokenAddr);
    frozonAssets = new HBRFrozenAssets(_tokenAddr);
    AuthorizedUser[msg.sender] = true;

    //init minuteWating to 4320 minutes (3 days), Synchronization time between different block-chain networks should be considered.
    minuteWating = 4320;
    //init noShowLimit to 10080 minutes (7 days)
    noShowLimit = 10080;
  }

  // 1eth : 2000hbr = ethTotal: hbrTotal; 3:6000 = x : 300 , x = 900/6000
  // ethTotal: hbrTotal = x : hbrRefund;
  function assetRate() public returns(uint){
    if(hbrTotal == 0 || ethTotal == 0){return 0;}

    if(equalizeLevel){
        return token.totalSupply.div(ethTotal);
      }else{
         return hbrTotal.div(ethTotal);
      }
  }



  //deposit  
  function deposit(address _addr,uint256 _hbr_amount) public onlyAuthorized payable returns(bool) {
    require((state == State.ActiveAll || state == State.OnlyDeposit));
    require(msg.value > 0);

    ethTotal = ethTotal.add(msg.value);
    hbrTotal = hbrTotal.add(_hbr_amount);
    accounts[_addr] = accounts[_addr].add(msg.value);

    return true;
  }

  function changeState(State _state) onlyAuthorized {
    state = _state;
    StateChanged();
  }

   function changeEqulizePolicy(bool _equalizeLevel) public onlyPolicyManager returns(bool) {
    equalizeLevel = _equalizeLevel
    return equalizeLevel;
  }

  //change Withdrawal Policy, limit to under 43200 minutes (30 days)
  function changeWithdrawalPolicy(uint _minuteWating, uint _noShowLimit) public onlyPolicyManager {
    require(_minuteWating <= 43200);
    require(_noShowLimit <= 43200);

    minuteWating = _minuteWating;
    noShowLimit = _noShowLimit;
  }

  function freeze(uint256 _amount) public onlyAuthorized{
    require(hbrTotal >= _amount);

    bool result = frozonAssets.freeze(_amount);
    if(result != true){
      revert();
    }
    hbrTotal = hbrTotal.add(_amount);
  }

  function melt(uint256 _amount) public onlyAuthorized{
    bool result = frozonAssets.melt(_amount);
    if(result != true){
      revert();
    }
    hbrTotal = hbrTotal.sub(_amount);
  }

//Reservation HBR to ETH, 
  function reservationWithdrawal(uint256 _amount) payable {
    require((state == State.ActiveAll || state == State.OnlyWithdrawl));
    require(token.balanceOf(msg.sender) >= _amount);

    if(reservation[msg.sender]){
      reservation[msg.sender].regDate = now;
      reservation[msg.sender].amount = _amount;
    }else{
      reservation[msg.sender] = Receipt({ regDate : now, amount: _amount});
    }
     
  }


  //exchange HBR to ETH and burn HBR
  function withdrawal(uint256 _amount) payable {
    require((state == State.ActiveAll || state == State.OnlyWithdrawl));
    require(token.balanceOf(msg.sender) >= _amount);
    require(reservation[msg.sender].amount >= _amount)


    uint startTime = reservation[msg.sender].regDate + (minuteWating * 1 minutes);
    uint endTime = startTime + (noShowLimit * 1 minutes);

    if(startTime <= now || endTime <= now) {
      revert('its not reserved time');
    }

    address _wallet = msg.sender;
    
    uint256 rate = assetRate();
    uint256 eth = _amount.div(rate);

    bool hasBurn = token.burn(_wallet,_amount);
    if(hasBurn == false){
      revert();
    }
    
    _wallet.transfer(eth);
    ethTotal = ethTotal.sub(eth);
    hbrTotal = hbrTotal.sub(_amount);

    Withdrawn(_wallet, eth);
  }

  //burn HBR everyone accessable
  function burnHBR(address _acc,uint256 _amount,bytes32 _info) {
    token.burn(_acc,_amount);
    hbrTotal = hbrTotal.sub(_amount);
    Burn(_acc,_amount,_info);
  }

}
