//pragma solidity ^0.4.11;
pragma solidity ^0.4.24;

import '../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol';
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
contract HBRAssetsEth is Authorized, PolicyManager {
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
  uint256 public ethTotal;
  //HBR issuance corresponding to deposited ETH 
  uint256 public hbrTotal;
  //Make ether the underlying asset of all assets.
  bool public equalizeLevel;

  event StateChanged();
  event Deposit(address indexed addr, uint256 eth_amount, uint256 hbr_amount);
  event Withdrawn(address indexed addr, uint256 weiAmount);
  event Burn(address indexed addr, uint256 amount);
  event WithdrowErc20Token (address indexed erc20, address indexed wallet, uint value);


  constructor(address _tokenAddr) public {
    state = State.ActiveAll;
    token = HarborToken(_tokenAddr);
    frozonAssets = new HBRFrozenAssets(_tokenAddr);
    AuthorizedUser[msg.sender] = true;

    //init minuteWating to 1440 minutes (1 days), Synchronization time between different block-chain networks should be considered.
    minuteWating = 1440;
    //init noShowLimit to 4320 minutes (3 days)
    noShowLimit = 4320;
  }

  // ethTotal: hbrTotal = x : hbrRefund;
  function assetRate() public view returns(uint256) {
    if(hbrTotal == 0 || ethTotal == 0){return 0;}

    if(equalizeLevel){
      uint256 totalsupply = token.totalSupply();
        return totalsupply.div(ethTotal);
      }else{
         return hbrTotal.div(ethTotal);
      }
  }

  //deposit asset
  function deposit(address _addr,uint256 _hbr_amount) external onlyAuthorized payable {
    require((state == State.ActiveAll || state == State.OnlyDeposit));
    require(msg.value > 0);

    ethTotal = ethTotal.add(msg.value);
    hbrTotal = hbrTotal.add(_hbr_amount);
    accounts[_addr] = accounts[_addr].add(msg.value);
  }

  function changeState(State _state) public onlyPolicyManager {
    state = _state;
    emit StateChanged();
  }

   function changeEqulizePolicy(bool _equalizeLevel) public onlyPolicyManager returns(bool) {
    equalizeLevel = _equalizeLevel;
    return equalizeLevel;
  }

  //change Withdrawal Policy, limit to under 43200 minutes (30 days) and noShowLimit must be at least 1 minute
  function changeWithdrawalPolicy(uint _minuteWating, uint _noShowLimit) public onlyPolicyManager {
    require(_minuteWating <= 43200);
    require(_noShowLimit >= 1);

    minuteWating = _minuteWating;
    noShowLimit = _noShowLimit;
  }

  //Increase supply and temporarily reduce asset value.
  function freeze(uint256 _amount) public onlyAuthorized{
    require(hbrTotal >= _amount);

    bool result = frozonAssets.freeze(_amount);
    if(result != true){
      revert();
    }
    hbrTotal = hbrTotal.add(_amount);
  }
  //Reduce virtual supply and restore asset value.
  function melt(uint256 _amount) public onlyAuthorized{
    bool result = frozonAssets.melt(_amount);
    if(result != true){
      revert();
    }
    hbrTotal = hbrTotal.sub(_amount);
  }

  //check reservation information
  function reservationAt(address _addr) public view returns(uint256, uint256) {
    return (reservation[_addr].regDate, reservation[_addr].amount);
  }
  //Reservation HBR to ETH, 
  function reservationWithdrawal(uint256 _amount) payable public {
    require((state == State.ActiveAll || state == State.OnlyWithdrawl));
    
    if(!equalizeLevel){
      if(token.balanceOf(msg.sender) < _amount){
        revert();
      }
    }

    reservation[msg.sender].regDate = now;
    reservation[msg.sender].amount = _amount;
     
  }

  //Check withdrawal possible
  function checkWithdrawal(address _addr, uint256 _amount) public view returns(bool) {
    if(state == State.StopAll || state == State.OnlyDeposit){
      return false;
    }

    if(token.balanceOf(_addr) < _amount){
      return false;
    }
    if(reservation[_addr].amount < _amount){
      return false;
    }
    uint startTime = reservation[_addr].regDate + (minuteWating * 1 minutes);
    uint endTime = startTime + (noShowLimit * 1 minutes);

    if(startTime > now) {
      return false;
    }

    if(endTime < now) {
      return false;
    }
    return true;
  }

  //exchange HBR to ETH and burn HBR
  function withdrawal(uint256 _amount) payable public {
    require((state == State.ActiveAll || state == State.OnlyWithdrawl));
    require(token.balanceOf(msg.sender) >= _amount);
    require(reservation[msg.sender].amount >= _amount);

    uint startTime = reservation[msg.sender].regDate + (minuteWating * 1 minutes);
    uint endTime = startTime + (noShowLimit * 1 minutes);

    if(startTime > now) {
      revert();
    }
    if(endTime < now) {
      revert();
    }

    address wallet = msg.sender;

    //remove reservation amount;
    reservation[msg.sender].amount = reservation[msg.sender].amount.sub(_amount);
    
    uint256 rate = assetRate();
    uint256 eth = _amount.div(rate);

    token.burn(wallet,_amount);
    emit Burn(wallet, _amount);

    wallet.transfer(eth);
    ethTotal = ethTotal.sub(eth);
    hbrTotal = hbrTotal.sub(_amount);

    emit Withdrawn(wallet, eth);
  }

  //burn HBR everyone accessable
  function burnHBR(uint256 _amount) public{
    require(_amount > 0);
    address burner = msg.sender;
    token.burn(burner,_amount);
    hbrTotal = hbrTotal.sub(_amount);
    emit Burn(burner,_amount);
  }

  //Authorized accounts can refund the wrong transfered erc20
  function withdrowErc20(address _tokenAddr, address _to, uint _value) public onlyAuthorized {
    ERC20 erc20 = ERC20(_tokenAddr);
    erc20.transfer(_to, _value);
    emit WithdrowErc20Token(_tokenAddr, _to, _value);
  }

}
