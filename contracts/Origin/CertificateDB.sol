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
// @authors: slock.it GmbH, Jonas Bentke, jonas.bentke@slock.it, Martin Kuechler, martin.kuechler@slock.it

pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

/// @title The Database contract for the Certificate of Origin list
/// @notice This contract only provides getter and setter methods

import "ew-utils-general-contracts/Msc/Owned.sol";
import "../../contracts/Origin/TradableEntityContract.sol";
import "../../contracts/Interfaces/EnergyInterface.sol";
import "../../contracts/Origin/EnergyDB.sol";

contract CertificateDB is EnergyInterface, Owned, TradableEntityContract {

    struct Certificate {
        TradableEntity tradableEntity;
        CertificateSpecific certificateSpecific;
    }

    struct CertificateSpecific {
        bool retired;
        string dataLog;
        uint coSaved;
        uint creationTime; 
        uint parentId;
        uint[] children;
        uint maxOwnerChanges;
        uint ownerChangeCounter;
    }

    /// @notice An array containing all created certificates
    Certificate[] private certificateList;
    mapping(address => uint) private tokenAmountMapping;
    mapping(address => mapping (address => bool)) ownerToOperators;

    /// @notice Constructor
    /// @param _certificateLogic The address of the corresbonding logic contract
    constructor(address _certificateLogic) Owned(_certificateLogic) public { }

    /**
        external functions
    */
    function addApproval(uint _entityId, address _approve) external onlyOwner {
        certificateList[_entityId].tradableEntity.approvedAddress = _approve;
    }

    /// @notice Adds a certificate-Id as child to an existing certificate
    /// @param _certificateId The array position in which the parent certificate is stored
    /// @param _childId The array position in which the child certificate is stored
    function addChildren(uint _certificateId, uint _childId) external onlyOwner {
        Certificate storage parent = certificateList[_certificateId];
        parent.certificateSpecific.children.push(_childId);
    }

/// @notice Adds a new escrow address to an existing certificate
    /// @param _escrow The new escrow-address
    function addEscrowForAsset(uint _entityId, address _escrow) external onlyOwner {
        certificateList[_entityId].tradableEntity.escrow.push(_escrow);
    }

    /// @notice sets the escrow-addresses of a certificate
    /// @param _certificateId certificateId
    /// @param _escrow new escrow-addresses
    function setCertificateEscrow(uint _certificateId, address[] _escrow)
        external
        onlyOwner
    {
        certificateList[_certificateId].tradableEntity.escrow = _escrow;
    }

    /// @notice Sets the owner of a certificate
    /// @param _entityId The array position in which the certificate is stored
    /// @param _owner The address of the new owner
    function setTradableEntityOwner(uint _entityId, address _owner) external onlyOwner {
        certificateList[_entityId].tradableEntity.owner = _owner;
    }

    function setTradableToken(uint _entityId, address _token) external onlyOwner {
        certificateList[_entityId].tradableEntity.acceptedToken = _token;
    }

    function setOnChainDirectPurchasePrice(uint _entityId, uint _price) external onlyOwner {
        certificateList[_entityId].tradableEntity.onChainDirectPurchasePrice = _price;
    }

    /// @notice Changes the OwnerChangeCounter of an existing certificate
    /// @param _certificateId The array position in which the parent certificate is stored
    function setOwnerChangeCounter(uint _certificateId, uint _newCounter) external onlyOwner {
        Certificate storage certificate = certificateList[_certificateId];
        certificate.certificateSpecific.ownerChangeCounter = _newCounter;
    }

    function setOwnerToOperators(address _company, address _escrow, bool _allowed) external onlyOwner {
        ownerToOperators[_company][_escrow] = _allowed;
    }

    /// @notice Removes an escrow-address of an existing certificate
    /// @param _certificateId The array position in which the parent certificate is stored
    /// @param _escrow the escrow-address to be removed
    function removeEscrow(uint _certificateId, address _escrow) external onlyOwner  returns (bool) {

        address[] storage escrows = certificateList[_certificateId].tradableEntity.escrow;
        for (uint i = 0; i < escrows.length; i++){
            if(escrows[i] == _escrow){
                escrows[i] = escrows[escrows.length-1];
                escrows.length--;
                return true;
            }
        }
    }

    /// @notice Sets a certificate to retired
    /// @param _certificateId The array position in which the certificate is stored
    function retireCertificate(uint _certificateId) external onlyOwner{
     
        Certificate storage certificate = certificateList[_certificateId];
        certificate.certificateSpecific.retired = true;
    }


    function getApproved(uint256 _entityId) onlyOwner external view returns (address){
        return certificateList[_entityId].tradableEntity.approvedAddress;
    }

    function getBalanceOf(address _owner) external onlyOwner view returns (uint){
        return tokenAmountMapping[_owner];
    }
    

    /// @notice Returns the certificate that corresponds to the given array id
    /// @param _certificateId The array position in which the certificate is stored
    /// @return Certificate as struct
    function getCertificate(uint _certificateId) 
        external 
        onlyOwner
        view 
        returns (Certificate) 
    {
        return certificateList[_certificateId];
    }

    /// @notice function to get the amount of all certificates
    /// @return the amount of all certificates
    function getCertificateListLength() external onlyOwner view returns (uint) {
        return certificateList.length;
    }  

    function getOnChainDirectPurchasePrice(uint _entityId) external view returns (uint){
        return certificateList[_entityId].tradableEntity.onChainDirectPurchasePrice;
    }

    function getOwnerToOperators(address _company, address _escrow) onlyOwner external view returns (bool){
        return ownerToOperators[_company][_escrow];
    }
    function getTradableEntity(uint _entityId) external view returns (TradableEntityContract.TradableEntity _entity){
        return certificateList[_entityId].tradableEntity;
    }

    function getTradableToken(uint _entityId) external view returns (address) {
        return certificateList[_entityId].tradableEntity.acceptedToken;
    }



    /**
        public functions
    */

    /// @notice Creates a new certificate
    /// @param _tradableEntity The tradeable entity specific properties
    /// @param _certificateSpecific The certificate specific properties
    /// @return The id of the certificate
    function createCertificate(
        TradableEntity _tradableEntity,
        CertificateDB.CertificateSpecific _certificateSpecific 
    ) 
        public 
        onlyOwner 
        returns 
        (uint _certId) 
    {
        _certId = certificateList.push(
            Certificate(
                _tradableEntity,
                _certificateSpecific
            )
        ) - 1;
    }    
}