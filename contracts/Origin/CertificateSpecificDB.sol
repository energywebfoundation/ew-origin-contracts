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

pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;

import "../../contracts/Interfaces/CertificateSpecificDBInterface.sol";
import "../../contracts/Origin/CertificateSpecificContract.sol";

import "ew-utils-general-contracts/contracts/Msc/Owned.sol";

contract CertificateSpecificDB is CertificateSpecificDBInterface, Owned {

    function addChildrenExternal(uint _certificateId, uint _childId) public onlyOwner {
        addChildren(_certificateId, _childId);
    }


	/// @notice Adds a certificate-Id as child to an existing certificate
	/// @param _certificateId The array position in which the parent certificate is stored
	/// @param _childId The array position in which the child certificate is stored
    function addChildren(uint _certificateId, uint _childId) public onlyOwner {
        getCertificateInternally(_certificateId).children.push(_childId);
    }

    function getCertificateSpecific(uint _certificateId) external view returns (CertificateSpecificContract.CertificateSpecific memory _certificate);
    function getCertificateInternally(uint _certificateId) internal view returns (CertificateSpecificContract.CertificateSpecific  storage _certificate);
    function setCertificateSpecific(uint _certificateId, CertificateSpecificContract.CertificateSpecific memory _certificate) public;
    
    function getRetired(uint _certificateId) external onlyOwner returns (bool){
        return getCertificateInternally(_certificateId).retired;
    }

    function setRetired(uint _certificateId, bool _retired) external onlyOwner {
        CertificateSpecificContract.CertificateSpecific storage certificate = getCertificateInternally(_certificateId);
        certificate.retired = _retired;
    }

    function getDataLog(uint _certificateId) external onlyOwner returns (string memory){
        return getCertificateInternally(_certificateId).dataLog;
    }

    function setDataLog(uint _certificateId, string calldata _newDataLog) external onlyOwner {
        CertificateSpecificContract.CertificateSpecific storage certificate = getCertificateInternally(_certificateId);
        certificate.dataLog = _newDataLog;
    }

    function getMaxOwnerChanges(uint _certificateId) external onlyOwner returns (uint){
        return getCertificateInternally(_certificateId).maxOwnerChanges;
    }

    function setMaxOwnerChanges(uint _certificateId, uint _newMaxOwnerChanges) external onlyOwner {
        CertificateSpecificContract.CertificateSpecific storage certificate = getCertificateInternally(_certificateId);
        certificate.maxOwnerChanges = _newMaxOwnerChanges;
    }

    function getOwnerChangeCounter(uint _certificateId) external onlyOwner returns (uint){
        return getCertificateInternally(_certificateId).ownerChangeCounter;
    }

    function setOwnerChangeCounter(uint _certificateId, uint _newOwnerChangeCounter) external {
        require(msg.sender == owner || msg.sender == address(this));
        CertificateSpecificContract.CertificateSpecific storage certificate = getCertificateInternally(_certificateId);
        certificate.ownerChangeCounter = _newOwnerChangeCounter;
    }

    function getCertificateChildrenLength(uint _certificateId)
        external
        onlyOwner
        view 
        returns (uint)
    {
        return getCertificateInternally(_certificateId).children.length;
    }

}