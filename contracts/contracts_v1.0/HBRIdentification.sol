//pragma solidity ^0.4.11;
pragma solidity ^0.4.24;

import './Authorized.sol';

/**
 * @title IntegrityService
 * @dev The identification contract confirms the identity of the investor for the purpose of kyc / aml.
 *
 * authority level
 * step 1 approve system
 * step 2 approve 3rd party
 * step 3 approve self 
 * step 4 approve self and system (3rd party)
 */
 
contract HBRIdentification is Authorized {

  mapping (address => bool)  IdentificationDb;

  event proven(address addr,bool isConfirm);

  //Identification check for KYC/AML
  function verify(address _addr) public view returns(bool) {
   return IdentificationDb[_addr];
  }

  //Register members whose identity information has been verified on the website by batch system, for KYC/AML
  function provenAddress(address _addr, bool _isConfirm) public onlyAuthorized {
    IdentificationDb[_addr] = _isConfirm;
    emit proven(_addr,_isConfirm);
  }
}
