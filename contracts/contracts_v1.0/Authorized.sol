pragma solidity ^0.4.11;

/**
 * @title Authorized
 * @dev The Authorized contract has an Authorized address, and provides basic authorization control
 */


contract Authorized {

  mapping (address => bool) public AuthorizedUser;
  event AuthorizedUserChanged(address indexed addr, bool state );

/**
 * @dev Authorized constructors grant default authorizations to contract authors.
 */
  function Authorized() {
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
    AuthorizedUserChanged(addr, state);
  }

}
