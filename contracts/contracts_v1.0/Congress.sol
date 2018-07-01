//pragma solidity ^0.4.11;
pragma solidity ^0.4.24;


/**
 * @title Congress
 * @dev The Congress contract has an congress address, and provides basic authorization control
 * At first,it is dictatorship. However, after the ICO, a congress of investors is created and the powers are transferred.
 */
contract Congress {
  address public congress;


  event CongressTransferred(address indexed previousCongress, address indexed newCongress);


  /**
   * @dev The Ownable constructor sets the original `congress` of the contract to the sender
   * account.
   */
  constructor() public {
    congress = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the congress.
   */
  modifier onlyDiscussable() {
    require(msg.sender == congress);
    _;
  }


  /**
   * @dev Allows the current congress to transfer control of the contract to a newCongress.
   * @param newCongress The address to transfer congress to.
   */
  function transferCongress(address newCongress) public onlyDiscussable {
    require(newCongress != address(0));      
    emit CongressTransferred(congress, newCongress);
    congress = newCongress;
  }

}
