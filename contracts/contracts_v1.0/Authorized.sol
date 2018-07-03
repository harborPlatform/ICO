//pragma solidity ^0.4.11;
pragma solidity ^0.4.24;

/**
 * @title Authorized
 * @dev The Authorized contract has an Authorized address, and provides basic authorization control
 *  it can be multiple authority.

 */


contract Authorized {
  mapping (address => bool) public AuthorizedUser;
  event AuthorizedUserChanged(address indexed addr, bool state );

/**
 * @dev Authorized constructors grant default authorizations to contract authors.
 */
  constructor() public{
    AuthorizedUser[msg.sender] = true;
  }

  modifier onlyAuthorized() {
    require(AuthorizedUser[msg.sender]);
    _;
  }

  /**
   * register and change authorized user
   */
  function setAuthorizedUser(address addr, bool state) onlyAuthorized public {
    AuthorizedUser[addr] = state;
    emit AuthorizedUserChanged(addr, state);
  }

}
