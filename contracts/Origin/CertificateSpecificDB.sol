// Copyright 2018 Energy Web Foundation
// This file is part of the Origin Application brought to you by the Energy Web Foundation,
// a global non-profit organization focused on accelerating blockchain technology across the energy sector, 
// incorporated in Zug, Switzerland.
//
// The Origin Application is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// This is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY and without an implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details, at <http://www.gnu.org/licenses/>.
//
// @authors: Martin Kuechler, martin.kuechler@slock.it

pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "../../contracts/Interfaces/CertificateSpecificDBInterface.sol";
import "../../contracts/Origin/CertificateSpecificContract.sol";

import "ew-utils-general-contracts/contracts/Msc/Owned.sol";

contract CertificateSpecificDB is CertificateSpecificDBInterface, Owned {

	/// @notice Adds a certificate-Id as child to an existing certificate
	/// @param _certificateId The array position in which the parent certificate is stored
	/// @param _childId The array position in which the child certificate is stored
    function addChildren(uint _certificateId, uint _childId) public onlyOwner {
        getCertificateInternally(_certificateId).children.push(_childId);
    }

    /**
        abstract functions
     */
	/// @notice gets the CertificateSpecific-struct
	/// @param _certificateId the certificate Id
	/// @return the CertificateSpecific-Struct
    function getCertificateSpecific(uint _certificateId) external view returns (CertificateSpecificContract.CertificateSpecific _certificate);
	
	/// @notice gets the certificate internally as storage pointer
	/// @param _certificateId the certificate Id
	/// @return the CertificateStruct internally
    function getCertificateInternally(uint _certificateId) internal view returns (CertificateSpecificContract.CertificateSpecific  storage _certificate);
	
    /// @notice sets the CertificateSpecific-struct
	/// @param _certificateId the certificate Id
	/// @param _certificate the new CertificateSpecific-struct
    function setCertificateSpecific(uint _certificateId, CertificateSpecificContract.CertificateSpecific  _certificate) public;
    
    /**
        external funcitons
     */
	/// @notice gets the retired-flag
	/// @param _certificateId the certificate Id
	/// @return the retired flag
    function getRetired(uint _certificateId) external onlyOwner returns (bool){
        return getCertificateInternally(_certificateId).retired;
    }

	/// @notice sets the retired-flag
	/// @param _certificateId the certificate Id
	/// @param _retired the retired-flag
    function setRetired(uint _certificateId, bool _retired) external onlyOwner {
        CertificateSpecificContract.CertificateSpecific storage certificate = getCertificateInternally(_certificateId);
        certificate.retired = _retired;
    }

	/// @notice get the data-log
	/// @param _certificateId the certificate Id
	/// @return the data-log
    function getDataLog(uint _certificateId) external onlyOwner returns (string){
        return getCertificateInternally(_certificateId).dataLog;
    }

	/// @notice set the data-log
	/// @param _certificateId the certificate Id
	/// @param _newDataLog the new data-log
    function setDataLog(uint _certificateId, string _newDataLog) external onlyOwner {
        CertificateSpecificContract.CertificateSpecific storage certificate = getCertificateInternally(_certificateId);
        certificate.dataLog = _newDataLog;
    }

	/// @notice gets the maximal amounf of owner changes
	/// @param _certificateId the certificate Id
	/// @return the maximal amount of owner changes
    function getMaxOwnerChanges(uint _certificateId) external onlyOwner returns (uint){
        return getCertificateInternally(_certificateId).maxOwnerChanges;
    }

	/// @notice sets the maxmimum of owner changes
	/// @param _certificateId the certificate Id
	/// @param _newMaxOwnerChanges the new maximal amounf of owner changes
    function setMaxOwnerChanges(uint _certificateId, uint _newMaxOwnerChanges) external onlyOwner {
        CertificateSpecificContract.CertificateSpecific storage certificate = getCertificateInternally(_certificateId);
        certificate.maxOwnerChanges = _newMaxOwnerChanges;
    }

	/// @notice gets the owner-change counter
	/// @param _certificateId the certificate Id
	/// @return the owner-change counter
    function getOwnerChangeCounter(uint _certificateId) external onlyOwner returns (uint){
        return getCertificateInternally(_certificateId).ownerChangeCounter;
    }

	/// @notice set the owner-change counter
	/// @param _certificateId the certificate Id
	/// @param _newOwnerChangeCounter the new owner-change counter
    function setOwnerChangeCounter(uint _certificateId, uint _newOwnerChangeCounter) external {
        require(msg.sender == owner || msg.sender == address(this));
        CertificateSpecificContract.CertificateSpecific storage certificate = getCertificateInternally(_certificateId);
        certificate.ownerChangeCounter = _newOwnerChangeCounter;
    }

	/// @notice gets the amount of children for a certificate
	/// @param _certificateId the certificate Id
	/// @return the amounf of children for a certificate
    function getCertificateChildrenLength(uint _certificateId)
        external
        onlyOwner
        view 
        returns (uint)
    {
        return getCertificateInternally(_certificateId).children.length;
    }

}