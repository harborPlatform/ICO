//pragma solidity ^0.4.11;
pragma solidity ^0.4.24;

/**
 * @title PolicyManager
 * @dev The Authorized contract has an Authorized address, and provides basic authorization control
 */


contract PolicyManager {

  mapping (address => bool) public policyAdmin;
  event PolicyManagerChanged(address indexed addr, bool state );

/**
 * @dev Authorized constructors grant default authorizations to contract authors.
 */
  constructor() public {
    policyAdmin[msg.sender] = true;
  }

  modifier onlyPolicyManager() {
    require(policyAdmin[msg.sender]);
    _;
  }

  /**
   * register and change authorized user
   */
  function setPolicyManager(address addr, bool state) onlyPolicyManager public {
    policyAdmin[addr] = state;
    emit PolicyManagerChanged(addr, state);
  }

}
