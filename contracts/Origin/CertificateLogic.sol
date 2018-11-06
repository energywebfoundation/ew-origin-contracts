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

import "ew-user-registry-contracts/contracts/Users/RoleManagement.sol";
import "../../contracts/Origin/CertificateDB.sol";
import "ew-asset-registry-contracts/contracts/Interfaces/AssetProducingInterface.sol";
import "../../contracts/Origin/TradableEntityContract.sol";
import "../../contracts/Origin/TradableEntityLogic.sol";
import "ew-asset-registry-contracts/contracts/Interfaces/AssetContractLookupInterface.sol";
import "../../contracts/Interfaces/OriginContractLookupInterface.sol";
import "../../contracts/Interfaces/CertificateInterface.sol";
import "../../contracts/Interfaces/ERC20Interface.sol";
import "../../contracts/Interfaces/TradableEntityDBInterface.sol";
import "ew-asset-registry-contracts/contracts/Interfaces/AssetGeneralInterface.sol";
import "ew-asset-registry-contracts/contracts/Asset/AssetProducingDB.sol";

import "../../contracts/Origin/CertificateSpecificDB.sol";

contract CertificateLogic is CertificateInterface, RoleManagement, TradableEntityLogic, TradableEntityContract {

    /// @notice Logs the creation of an event
    event LogCreatedCertificate(uint indexed _certificateId, uint powerInW, address owner);
    event LogCertificateRetired(uint indexed _certificateId, bool _retire);
    event LogCertificateSplit(uint indexed _certificateId, uint _childOne, uint _childTwo);
 
    constructor(
        AssetContractLookupInterface _assetContractLookup,
        OriginContractLookupInterface _originContractLookup
    )
        TradableEntityLogic(_assetContractLookup, _originContractLookup)  public { }

    /**
        ERC721 functions to overwrite
     */

	/// @notice transfers a certificate secureley
	/// @param _from the current owner of the certificate
	/// @param _to the new owner of the certificate
	/// @param _entityId the certificate id
	/// @param _data the data
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

	/// @notice transfers a certificate securely
	/// @param _from the current owner of the certificate
	/// @param _to the new owner of the certificate
	/// @param _entityId the certificate id
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

	/// @notice transfers a certificate
	/// @param _from the current owner
	/// @param _to the new owner
	/// @param _entityId the certificate id
    function transferFrom(address _from, address _to, uint256 _entityId) 
        onlyRole(RoleManagement.Role.Trader) 
        external 
        payable 
    {
        CertificateDB.Certificate memory cert = CertificateDB(db).getCertificate(_entityId);
        simpleTransferInternal(_from, _to, _entityId);
     //   emit LogCertificateOwnerChanged(_entityId, cert.tradableEntity.owner, _to, 0x0);
        checktransferOwnerInternally(_entityId, cert);
    }


    /**
        external functions
    */    

	/// @notice buys a certificate
	/// @param _certificateId the certificate Id
    function buyCertificate(uint _certificateId) 
        external
        onlyRole(RoleManagement.Role.Trader)
     {
        CertificateDB.Certificate memory cert = CertificateDB(db).getCertificate(_certificateId);
        require(cert.tradableEntity.acceptedToken != address(0x0),"0x0 not allowed");

        require(ERC20Interface(cert.tradableEntity.acceptedToken).transferFrom(msg.sender, cert.tradableEntity.owner, cert.tradableEntity.onChainDirectPurchasePrice),"erc20 transfer failed");
        TradableEntityDBInterface(db).addApproval(_certificateId, msg.sender);

        simpleTransferInternal(cert.tradableEntity.owner, msg.sender, _certificateId);
        checktransferOwnerInternally(_certificateId, cert);    

    }
     
	/// @notice Request a certificate to retire. Only Certificate owner can retire
	/// @param _certificateId The id of the certificate
    function retireCertificate(uint _certificateId) external  { 
        CertificateDB.Certificate memory cert = CertificateDB(db).getCertificate(_certificateId);
        require(cert.tradableEntity.owner == msg.sender,"retire: not the Certificate-Owner");
        require(cert.certificateSpecific.children.length == 0,"retire: certificate has been splitted");
        if (!cert.certificateSpecific.retired) {
            retireCertificateAuto( _certificateId);
        }
    }

	/// @notice Splits a certificate into two smaller ones, where (total - _power = 2ndCertificate)
	/// @param _certificateId The id of the certificate
	/// @param _power the power the power of the 1st child
    function splitCertificate(uint _certificateId, uint _power) external
    {
        CertificateDB.Certificate memory parent = CertificateDB(db).getCertificate(_certificateId);
        require (msg.sender == parent.tradableEntity.owner || checkMatcher(parent.tradableEntity.escrow),"split: not the owner or escrow");
        require(parent.tradableEntity.powerInW > _power,"split: power too high");
        require(!parent.certificateSpecific.retired,"split: parent is already retired"); 
        require(parent.certificateSpecific.children.length == 0,"split: parent has already been splitted");

        (uint childIdOne,uint childIdTwo) = CertificateDB(db).createChildCertificate(_certificateId, _power);
        emit Transfer(0, parent.tradableEntity.owner, childIdOne);
        emit Transfer(0, parent.tradableEntity.owner, childIdTwo);
        emit LogCertificateSplit(_certificateId, childIdOne,childIdTwo);
        
    }

	/// @notice get a certificate as struct
	/// @param _certificateId the certificate Id
	/// @return the Certificate-struct
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
	/// @return the newly created certificate id
    function createCertificate(uint _assetId, uint _powerInW) 
        public 
        onlyAccount(address(assetContractLookup.assetProducingRegistry()))
        returns (uint) 
    {
        AssetProducingDB.Asset memory asset =  AssetProducingInterface(address(assetContractLookup.assetProducingRegistry())).getAssetById(_assetId);

        uint certId = CertificateDB(db).createCertificateRaw(_assetId, _powerInW, asset.assetGeneral.matcher, asset.assetGeneral.owner, asset.assetGeneral.lastSmartMeterReadFileHash, asset.maxOwnerChanges); 
        emit Transfer(0,  asset.assetGeneral.owner, certId);

        emit LogCreatedCertificate(certId, _powerInW, asset.assetGeneral.owner);
        return certId;
    
    }

    /**
        internal functions
    */

	/// @notice Retires a certificate
	/// @param _certificateId The id of the requested certificate
    function retireCertificateAuto(uint _certificateId) internal{
        db.setTradableEntityEscrow(_certificateId, new address[](0));
        CertificateSpecificDB(db).setRetired(_certificateId, true);
        emit LogCertificateRetired(_certificateId, true);
    }

	/// @notice internal function for safeTransfer
    /// @dev function checks all the requirements for a safeTransfer
	/// @param _from the from
	/// @param _to the to
	/// @param _entityId the entity Id
	/// @param _data the data
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
     //   emit LogCertificateOwnerChanged(_entityId, cert.tradableEntity.owner, _to, 0x0);
        checktransferOwnerInternally(_entityId, cert);
    }

	/// @notice Transfers the ownership, checks if the requirements are met
	/// @param _certificateId The id of the requested certificate
	/// @param _certificate The certificate where the ownership should be transfered
    function checktransferOwnerInternally(uint _certificateId, CertificateDB.Certificate _certificate) internal {
        require(_certificate.certificateSpecific.children.length == 0,"changeOwner: Certificate has been splitted");
        require(!_certificate.certificateSpecific.retired,"changeOwner: certificate is retired");
        require(_certificate.certificateSpecific.ownerChangeCounter < _certificate.certificateSpecific.maxOwnerChanges," changeOwner: max-Owner change reached");
        uint ownerChangeCounter = _certificate.certificateSpecific.ownerChangeCounter + 1;

        CertificateDB(db).setOwnerChangeCounterResetEscrow(_certificateId,ownerChangeCounter);

        if(_certificate.certificateSpecific.maxOwnerChanges <= ownerChangeCounter){
           // CertificateDB(db).setCertificateEscrow(_certificateId, new address[](0));
            CertificateSpecificDB(db).setRetired(_certificateId, true);
            emit LogCertificateRetired(_certificateId, true);
        }
    }
}
