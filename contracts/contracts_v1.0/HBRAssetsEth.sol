pragma solidity ^0.4.11;

import '../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol';
import './Authorized.sol';
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

  mapping (address => uint256) public accounts;

  HarborToken public token;
  HBRFrozenAssets public frozonAssets;

  //asset state
  State public state;
  //ETH reserves for refunds (fundamental asset)
  uint public ethTotal;
  //HBR issuance corresponding to deposited ETH 
  uint public hbrTotal;

  event StateChanged();
  event Deposit(address indexed addr,uint256 eth_amount,uint256 hbr_amount);
  event Withdrawn(address indexed addr, uint256 weiAmount);
  event Burn(address indexed addr, uint256 amount, bytes32 info);

  function HBRAssetsEth(address _tokenAddr) {
    state = State.ActiveAll;
    token = HarborToken(_tokenAddr);
    frozonAssets = new HBRFrozenAssets(_tokenAddr);
    AuthorizedUser[msg.sender] = true;
  }
  // 1eth : 2000hbr = ethTotal: hbrTotal; 3:6000 = x : 300 , x = 900/6000
  // ethTotal: hbrTotal = x : hbrRefund;
  function assetRate() public returns(uint){
    if(hbrTotal == 0 || ethTotal == 0){return 0;}
    return hbrTotal.div(ethTotal);
  }

  //deposit  
  function deposit(address _addr,uint256 _hbr_amount) onlyAuthorized payable returns(bool) {
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

  //exchange HBR to ETH and burn HBR
  function withdrawal(uint256 _amount) payable {
    require((state == State.ActiveAll || state == State.OnlyWithdrawl));
    require(token.balanceOf(msg.sender) >= _amount);

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


  function test1() public returns (bytes32){
    return 'test1 ok!!!';
  }

  bool aaa=false;
  function test2(){
    aaa = true;
  }
}
