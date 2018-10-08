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

/// @title The logic contract for the Certificate of Origin list
/// @notice This contract provides the logic that determines how the data is stored
/// @dev Needs a valid CertificateDB(db) contract to function correctly

import "ew-user-registry-contracts/Users/RoleManagement.sol";
import "../../contracts/Origin/CertificateDB.sol";
import "ew-asset-registry-contracts/Interfaces/AssetProducingInterface.sol";
import "ew-asset-registry-contracts/Asset/AssetProducingRegistryDB.sol";
import "../../contracts/Origin/TradableEntityContract.sol";
import "../../contracts/Origin/TradableEntityLogic.sol";
import "ew-asset-registry-contracts/Interfaces/AssetContractLookupInterface.sol";
import "../../contracts/Interfaces/OriginContractLookupInterface.sol";
import "../../contracts/Interfaces/CertificateInterface.sol";
import "../../contracts/Interfaces/ERC20Interface.sol";


contract CertificateLogic is CertificateInterface, RoleManagement, TradableEntityLogic, TradableEntityContract {

    /// @notice Logs the creation of an event
    event LogCreatedCertificate(uint indexed _certificateId, uint powerInW, address owner);
    event LogCertificateRetired(uint indexed _certificateId, bool _retire);
    event LogCertificateOwnerChanged(uint indexed _certificateId, address _oldOwner, address _newOwner, address _oldEscrow);
    event LogCertificateSplit(uint indexed _certificateId, uint _childOne, uint _childTwo);
    event LogEscrowRemoved(uint indexed _certificateId, address _escrow);
    event LogEscrowAdded(uint indexed _certificateId, address _escrow);
    
        
  //  AssetContractLookupInterface public assetContractLookup;

    constructor(
        AssetContractLookupInterface _assetContractLookup,
        OriginContractLookupInterface _originContractLookup
    )
        TradableEntityLogic(_assetContractLookup, _originContractLookup) 
    public {
    //    assetContractLookup = _assetContractLookup;
    }

    /**
        ERC721 functions to overwrite
     */

    function safeTransferFrom(
        address _from, 
        address _to, 
        uint256 _entityId, 
        bytes _data
    ) 
        onlyRole(RoleManagement.Role.Trader) 
        external payable 
    {
        internalSafeTransfer(_from, _to, _entityId, _data);
    }

    function safeTransferFrom(
        address _from, 
        address _to, 
        uint256 _entityId
    )  
        onlyRole(RoleManagement.Role.Trader) 
        external payable 
    {
        bytes memory data = "";
        internalSafeTransfer(_from, _to, _entityId, data);
    }

    function transferFrom(address _from, address _to, uint256 _entityId) 
        onlyRole(RoleManagement.Role.Trader) 
        external 
        payable 
    {
        CertificateDB.Certificate memory cert = CertificateDB(db).getCertificate(_entityId);
        simpleTransferInternal(_from, _to, _entityId);
        emit LogCertificateOwnerChanged(_entityId, cert.tradableEntity.owner, _to, 0x0);
        checktransferOwnerInternally(_entityId, cert);
    }


    /**
        external functions
    */

    /// @notice adds a new escrow address to a certificate
    /// @param _certificateId The id of the certificate
    /// @param _escrow The additional escrow address
    function addEscrowForAsset(uint _certificateId, address _escrow) external {
        require(
            (CertificateDB(db).getTradableEntityOwner(_certificateId) == msg.sender)
            && (CertificateDB(db).getTradableEntityEscrowLength(_certificateId) < OriginContractLookupInterface(owner).maxMatcherPerAsset()));
        db.addEscrowForAsset(_certificateId, _escrow);
        emit LogEscrowAdded(_certificateId, _escrow);
    }
 

    function buyCertificate(uint _certificateId) 
        external
        onlyRole(RoleManagement.Role.Trader)
     {
        CertificateDB.Certificate memory cert = CertificateDB(db).getCertificate(_certificateId);
        require(cert.tradableEntity.acceptedToken != address(0x0));

        require(ERC20Interface(cert.tradableEntity.acceptedToken).transferFrom(msg.sender, cert.tradableEntity.owner, cert.tradableEntity.onChainDirectPurchasePrice));
        db.addApproval(_certificateId, msg.sender);

        simpleTransferInternal(cert.tradableEntity.owner, msg.sender, _certificateId);
      //  emit Transfer(cert.tradableEntity.owner, msg.sender, _certificateId);
        checktransferOwnerInternally(_certificateId, cert);    

    }
     
    /// @notice Request a certificate to retire. Only Certificate owner can retire
    /// @param _certificateId The id of the certificate
    function retireCertificate(uint _certificateId) external {
        CertificateDB.Certificate memory cert = CertificateDB(db).getCertificate(_certificateId);
        require(cert.tradableEntity.owner == msg.sender);
        require(cert.certificateSpecific.children.length == 0);
        if (!cert.certificateSpecific.retired) {
            retireCertificateAuto( _certificateId);
        }
    }

    /// @notice Removes an escrow-address of a certifiacte
    /// @param _certificateId The id of the certificate
    /// @param _escrow The address to be removed
    function removeEscrow(uint _certificateId, address _escrow) external {
        require(CertificateDB(db).getTradableEntityOwner(_certificateId) == msg.sender);
        require(CertificateDB(db).removeEscrow(_certificateId, _escrow));
        emit LogEscrowRemoved(_certificateId, _escrow);
    }

    /// @notice Splits a certificate into two smaller ones, where (total - _power = 2ndCertificate)
    /// @param _certificateId The id of the certificate
    /// @param _certificateId The amount of power in W for the 1st certificate
    function splitCertificate(uint _certificateId, uint _power) external
    {
        CertificateDB.Certificate memory parent = CertificateDB(db).getCertificate(_certificateId);
        require (msg.sender == parent.tradableEntity.owner || checkMatcher(parent.tradableEntity.escrow));
        require(parent.tradableEntity.powerInW > _power);
        require(!parent.certificateSpecific.retired); 
        require(parent.certificateSpecific.children.length == 0);

        (uint childIdOne,uint childIdTwo) = CertificateDB(db).createChildCertificate(_certificateId, _power);
        emit Transfer(0, parent.tradableEntity.owner, childIdOne);
        emit Transfer(0, parent.tradableEntity.owner, childIdTwo);
        emit LogCertificateSplit(_certificateId, childIdOne,childIdTwo);
        
    }

    /// @notice function to allow an escrow-address to change the ownership of a certificate
    /// @dev this function can only be called by the demandLogic
    /// @param _certificateId the certificate-id
    /// @param _newOwner the new owner of the certificate
    function transferOwnershipByEscrow(uint _certificateId, address _newOwner) 
        external 
    {   
        CertificateDB.Certificate memory certificate = CertificateDB(db).getCertificate(_certificateId);
        require (checkMatcher(certificate.tradableEntity.escrow));
        
        emit LogCertificateOwnerChanged(_certificateId, certificate.tradableEntity.owner, _newOwner, msg.sender);
        simpleTransferInternal(certificate.tradableEntity.owner,_newOwner, _certificateId);
        checktransferOwnerInternally(_certificateId, certificate);
    }

    function getCertificate(uint _certificateId) external view returns (CertificateDB.Certificate memory certificate)
    {
        return CertificateDB(db).getCertificate(_certificateId);
    }

    /// @notice Getter for the length of the list of certificates
    /// @return the length of the array
    function getCertificateListLength() external view returns (uint) {
        return CertificateDB(db).getCertificateListLength();
    }

    /// @notice Getter for a specific Certificate
    /// @param _certificateId The id of the requested certificate
    /// @return the certificate as single values
    function getCertificateOwner(uint _certificateId) external view returns (address) {
        return CertificateDB(db).getCertificate(_certificateId).tradableEntity.owner;
    }

    /// @notice Getter for a specific Certificate
    /// @param _certificateId The id of the requested certificate
    /// @return the certificate as single values
    function isRetired(uint _certificateId) external view returns (bool) {
        return CertificateDB(db).getCertificate(_certificateId).certificateSpecific.retired;
    }

    /**
        public functions
    */

    /// @notice Creates a certificate of origin. Checks in the AssetRegistry if requested wh are available.
    /// @param _assetId The id of the asset that generated the energy for the certificate 
    /// @param _powerInW The amount of Watts the Certificate holds
    /// @param _cO2Saved The amount of CO2 saved
    /// @param _escrow The escrow-addresses
    function createCertificate(uint _assetId, uint _powerInW, uint _cO2Saved, address[] _escrow) 
        external 
        onlyAccount(address(assetContractLookup.assetProducingRegistry()))
        returns (uint) 
    {
        AssetProducingRegistryDB.Asset memory asset = AssetProducingInterface(address(assetContractLookup.assetProducingRegistry())).getFullAsset(_assetId);

        uint certId = CertificateDB(db).createCertificateRaw(_assetId,  _powerInW,  _cO2Saved,  _escrow[0], asset.owner, asset.lastSmartMeterReadFileHash, asset.maxOwnerChanges); 
        emit Transfer(0,  asset.owner, certId);

        emit LogCreatedCertificate(certId, _powerInW, asset.owner);
        return certId;
    
    }

    /**
        internal functions
    */

    /// @notice Retires a certificate
    /// @param _certificateId The id of the requested certificate
    function retireCertificateAuto(uint _certificateId) internal{
     //   CertificateDB(db).setCertificateEscrow(_certificateId, empty);
        CertificateDB(db).retireCertificate(_certificateId);
        emit LogCertificateRetired(_certificateId, true);
    }

    function internalSafeTransfer(
        address _from, 
        address _to, 
        uint256 _entityId, 
        bytes _data
    )
        internal
    {
        CertificateDB.Certificate memory cert = CertificateDB(db).getCertificate(_entityId);
        simpleTransferInternal(_from, _to, _entityId);
        safeTransferChecks(_from, _to, _entityId, _data);
        emit LogCertificateOwnerChanged(_entityId, cert.tradableEntity.owner, _to, 0x0);
        checktransferOwnerInternally(_entityId, cert);
    }
    /// @notice Transfers the ownership, checks if the requirements are met
    /// @param _certificateId The id of the requested certificate
    /// @param _certificate The certificate where the ownership should be transfered
    function checktransferOwnerInternally(uint _certificateId, CertificateDB.Certificate _certificate) internal {
        require(_certificate.certificateSpecific.children.length == 0);
        require(!_certificate.certificateSpecific.retired);
        require(_certificate.certificateSpecific.ownerChangeCounter < _certificate.certificateSpecific.maxOwnerChanges);
        uint ownerChangeCounter = _certificate.certificateSpecific.ownerChangeCounter + 1;

        CertificateDB(db).setOwnerChangeCounterResetEscrow(_certificateId,ownerChangeCounter);

        if(_certificate.certificateSpecific.maxOwnerChanges <= ownerChangeCounter){
           // CertificateDB(db).setCertificateEscrow(_certificateId, new address[](0));
            CertificateDB(db).retireCertificate(_certificateId);
            emit LogCertificateRetired(_certificateId, true);
        }
    }

    function simpleTransferInternal(address _from, address _to, uint256 _entityId) internal {
        TradableEntityContract.TradableEntity memory te = CertificateDB(db).getTradableEntity(_entityId);

        require(
            (te.owner == _from) 
            &&(_to != 0x0) 
            && (te.owner != 0x0) 
            && (msg.value == 0) 
            &&  (te.owner == msg.sender || checkMatcher(te.escrow)|| db.getOwnerToOperators(te.owner, msg.sender) || te.approvedAddress == msg.sender )
        );
        
        CertificateDB(db).setTradableEntityOwnerAndAddApproval(_entityId, _to,0x0);
        emit Transfer(_from,_to,_entityId);
      
    }
}
