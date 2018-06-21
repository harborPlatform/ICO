pragma solidity ^0.4.11;

import '../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol';
import '../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol';
import './HarborToken.sol';

/**
 * @title FrozenAssets
 * @dev This is a contract to temporarily adjust the HBR volume and asset exchange rate.
 * it can only access by assets contract
 * Pegging assets or Release pegged assets (It is temporary, and so the effect is not much.)
 * Defence bankrun due to sudden rise in asset prices.
 */
contract HBRFrozenAssets is Ownable {
  using SafeMath for uint256;
  HarborToken token;

  event Frozen(uint256 amount);
  event Melted(uint256 amount);

  function HBRFrozenAssets(address _tokenAddr){
  	token = HarborToken(_tokenAddr);
  }

  uint public frozenTotal;

  //Temporarily,increase the total supply.
  function freeze(uint256 _amount) returns (bool){
    token.mint(address(this),_amount);
  	frozenTotal = frozenTotal.add(_amount);
  	Frozen(_amount);
    return true;
  }
  //Temporarily, decrease the total supply.
  function melt(uint256 _amount) returns (bool){
    require(frozenTotal >= _amount);

    token.burn(address(this),_amount);
    frozenTotal = frozenTotal.sub(_amount);
    Melted(_amount);
    return true;
   }

}