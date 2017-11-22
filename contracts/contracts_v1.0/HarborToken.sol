pragma solidity ^0.4.11;


import '../node_modules/zeppelin-solidity/contracts/token/StandardToken.sol';
import '../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol';

/**
 * @title Harbor token
 * @dev Simple ERC20 Token example, with mintable token creation
 * @dev Issue: * https://github.com/OpenZeppelin/zeppelin-solidity/issues/120
 * Based on code by TokenMarketNet: https://github.com/TokenMarketNet/ico/blob/master/contracts/MintableToken.sol
 */

contract HarborToken is StandardToken, Ownable {

  //define HarborToken
  string public constant name = "HarborToken";
  string public constant symbol = "HBR";
  uint8 public constant decimals = 18;

   /** List of agents that are allowed to create new tokens */
  mapping (address => bool) public mintAgents;

  event Mint(address indexed to, uint256 amount);
  event MintOpened();
  event MintFinished();
  event MintingAgentChanged(address addr, bool state  );
  event BurnToken(address addr,uint256 amount);

  bool public mintingFinished = false;

  modifier canMint() {
    require(!mintingFinished);
    _;
  }

  modifier onlyMintAgent() {
    // Only crowdsale contracts are allowed to mint new tokens
    require(mintAgents[msg.sender]);
    _;
  }

  function HarborToken(){
    setMintAgent(msg.sender,true);
  }

  /**
   * Owner can allow a crowdsale contract to mint new tokens.
   */
  function setMintAgent(address addr, bool state) onlyOwner public {
    mintAgents[addr] = state;
    MintingAgentChanged(addr, state);
  }

  /**
   * @dev Function to mint tokens
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) onlyMintAgent canMint returns (bool) {
    totalSupply = totalSupply.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    Mint(_to, _amount);
    Transfer(0x0, _to, _amount);
    return true;
  }

  /**
   * @dev Function to burn down tokens
   * @param _addr The address that will burn the tokens.
   * @param  _amount The amount of tokens to burn.
   * @return A boolean that indicates if the burn up was successful.
   */
  function burn(address _addr,uint256 _amount) onlyMintAgent canMint  returns (bool) {
    require(_amount > 0);
    require(balances[_addr] >= _amount);
    totalSupply = totalSupply.sub(_amount);
    balances[_addr] = balances[_addr].sub(_amount);
    BurnToken(_addr,_amount);
    return true;
  }

  /**
   * @dev Function to resume minting new tokens.
   * @return True if the operation was successful.
   */
  function openMinting() onlyOwner returns (bool) {
    mintingFinished = false;
    MintOpened();
     return true;
  }

 /**
   * @dev Function to stop minting new tokens.
   * @return True if the operation was successful.
   */
  function finishMinting() onlyOwner returns (bool) {
    mintingFinished = true;
    MintFinished();
    return true;
  }


}
