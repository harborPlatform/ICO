//pragma solidity ^0.4.11;
pragma solidity ^0.4.24;


import '../node_modules/openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol';
import './Ownable.sol';
import './Congress.sol';
/**
 * @title Harbor token
 * @dev Simple ERC20 Token example, with mintable token creation
 * @dev Issue: * https://github.com/OpenZeppelin/zeppelin-solidity/issues/120
 * Based on code by TokenMarketNet: https://github.com/TokenMarketNet/ico/blob/master/contracts/MintableToken.sol
 */

contract HarborToken is StandardToken, Ownable, Congress {

  //define HarborToken
  string public constant name = "HarborToken";
  string public constant symbol = "HBR";
  uint8 public constant decimals = 18;

   /** List of agents that are allowed to create new tokens */
  mapping (address => bool) public mintAgents;

  event Mint(address indexed to, uint256 amount);
  event MintOpened();
  event MintFinished();
  event MintingAgentChanged(address indexed addr, bool state  );
  event BurnToken(address indexed addr,uint256 amount);
  event WithdrowErc20Token (address indexed erc20, address indexed wallet, uint value);

  bool public mintingFinished = false;

  modifier canMint() {
    require(!mintingFinished);
    _;
  }

  modifier onlyMintAgent() {
    // Only specific addresses contracts are allowed to mint new tokens
    require(mintAgents[msg.sender]);
    _;
  }

  constructor() public {
    setMintAgent(msg.sender,true);
  }

  /**
   * Congress can regulate new token issuance by contract.
   */
  function setMintAgent(address addr, bool state) public onlyDiscussable {
    mintAgents[addr] = state;
    emit MintingAgentChanged(addr, state);
  }

  /**
   * @dev Function to mint tokens
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) public onlyMintAgent canMint {
    totalSupply_ = totalSupply_.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    emit Mint(_to, _amount);
    emit Transfer(address(0), _to, _amount);
  }

  /**
   * @dev Function to burn down tokens
   * @param _addr The address that will burn the tokens.
   * @param  _amount The amount of tokens to burn.
   * @return A boolean that indicates if the burn up was successful.
   */
  function burn(address _addr,uint256 _amount) public onlyMintAgent canMint {
    require(_addr != address(0));
    require(_amount > 0);
    require(balances[_addr] >= _amount);
    totalSupply_ = totalSupply_.sub(_amount);
    balances[_addr] = balances[_addr].sub(_amount);
    emit BurnToken(_addr,_amount);
    emit Transfer(_addr, address(0), _amount);
  }



  /**
   * @dev Function to resume minting new tokens.
   * @return True if the operation was successful.
   */
  function openMinting() public onlyOwner returns (bool) {
    mintingFinished = false;
    emit MintOpened();
     return true;
  }

 /**
   * @dev Function to stop minting new tokens.
   * @return True if the operation was successful.
   */
  function finishMinting() public onlyOwner returns (bool) {
    mintingFinished = true;
    emit MintFinished();
    return true;
  }


/** pauseable**/

  event Pause();
  event Unpause();

  bool public paused = false;
  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    emit Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() onlyOwner whenPaused public {
    paused = false;
    emit Unpause();
  }
 function transfer(address _to, uint256 _value) public whenNotPaused  returns (bool) {
    return super.transfer(_to, _value);
  }

  function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }

  function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {
    return super.approve(_spender, _value);
  }

  function increaseApproval(address _spender, uint _addedValue) public whenNotPaused returns (bool success) {
    return super.increaseApproval(_spender, _addedValue);
  }

  function decreaseApproval(address _spender, uint _subtractedValue) public whenNotPaused returns (bool success) {
    return super.decreaseApproval(_spender, _subtractedValue);
  }

  //Owner can refund the wrong transfered erc20
  function withdrowErc20(address _tokenAddr, address _to, uint _value) public onlyOwner {
    ERC20 erc20 = ERC20(_tokenAddr);
    erc20.transfer(_to, _value);
    emit WithdrowErc20Token(_tokenAddr, _to, _value);
  }

}
