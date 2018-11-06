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

import "../../contracts/Origin/TradableEntityContract.sol";
import "../../contracts/Origin/EnergyDB.sol";
import "../../contracts/Origin/TradableEntityDB.sol";
import "../../contracts/Origin/CertificateSpecificContract.sol";
import "../../contracts/Origin/CertificateSpecificDB.sol";

contract CertificateDB is TradableEntityDB, TradableEntityContract, CertificateSpecificContract, CertificateSpecificDB {

    struct Certificate {
        TradableEntity tradableEntity;
        CertificateSpecific certificateSpecific;
    }

    /// @notice An array containing all created certificates
    Certificate[] private certificateList;

    /// @notice Constructor
    /// @param _certificateLogic The address of the corresbonding logic contract
    constructor(address _certificateLogic) TradableEntityDB(_certificateLogic) public { }

    /**
        external functions
    */
	/// @notice sets the ownerchange-counter and resets the escrow-array
	/// @dev should be used after a transfer
	/// @param _certificateId the certificate Id
	/// @param _newCounter the new Counter
    function setOwnerChangeCounterResetEscrow(uint _certificateId, uint _newCounter) external  {
        require(msg.sender == owner || msg.sender == address(this));
        this.setOwnerChangeCounter(_certificateId, _newCounter);
        setTradableEntityEscrow(_certificateId, new address[](0));
    }

	/// @notice Returns the certificate that corresponds to the given array id
	/// @param _certificateId The array position in which the certificate is stored
	/// @return Certificate as struct
    function getCertificate(uint _certificateId) 
        public 
        onlyOwner
        view 
        returns (Certificate) 
    {
        return certificateList[_certificateId];
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
        CertificateSpecific _certificateSpecific 
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
        tokenAmountMapping[_tradableEntity.owner]++;
    }    

	/// @notice creates a raw Certificate in the DB
	/// @param _assetId the asset Id
	/// @param _powerInW the power In W
	/// @param _escrow the escrow-array
	/// @param _assetOwner the asset-owner
	/// @param _lastSmartMeterReadFileHash filehash of the last smartmeter-reading
	/// @param _maxOwnerChanges the amount of allowed owner-changes
	/// @return the asset-id
    function createCertificateRaw(
        uint _assetId, 
        uint _powerInW, 
        address[] _escrow,
        address _assetOwner,
        string _lastSmartMeterReadFileHash,
        uint _maxOwnerChanges
    ) 
        public
        onlyOwner
        returns (uint _certId)
    {
        TradableEntity memory tradableEntity = TradableEntity({
            assetId: _assetId,
            owner: _assetOwner,
            powerInW: _powerInW,
            acceptedToken: 0x0,
            onChainDirectPurchasePrice: 0,
            escrow: _escrow,
            approvedAddress: 0x0

        });

        CertificateDB.CertificateSpecific memory certificateSpecific= CertificateSpecific({
            retired: false,
            dataLog: _lastSmartMeterReadFileHash,
            creationTime: block.timestamp,
            parentId: getCertificateListLength(),
            children: new uint256[](0),
            maxOwnerChanges: _maxOwnerChanges,
            ownerChangeCounter: 0
        });
        
        _certId = createCertificate(
            tradableEntity,  
            certificateSpecific
        );
    }

	/// @notice Creates a new certificate
	/// @param _parentId the parent Id
	/// @param _power the power
	/// @return The id of the certificate
    function createChildCertificate(
        uint _parentId,
        uint _power
    ) 
        public 
        onlyOwner 
        returns 
        (uint _childIdOne, uint _childIdTwo) 
    {
        Certificate memory parent = certificateList[_parentId];

        TradableEntity memory childOneEntity = TradableEntity({
            assetId: parent.tradableEntity.assetId,
            owner: parent.tradableEntity.owner,
            powerInW: _power,
            acceptedToken: 0x0,
            onChainDirectPurchasePrice: 0,
            escrow: parent.tradableEntity.escrow,
            approvedAddress: parent.tradableEntity.approvedAddress
         //   acceptedToken: parent.tradableEntity.acceptedToken,
         //   onChainDirectPurchasePrice: (parent.tradableEntity.onChainDirectPurchasePrice*(_power*100000000000/parent.tradableEntity.powerInW)/100000000000)
        });

        CertificateDB.CertificateSpecific memory certificateSpecificOne = CertificateSpecific({
            retired: false,
            dataLog: parent.certificateSpecific.dataLog,
            creationTime: parent.certificateSpecific.creationTime,
            parentId: _parentId,
            children: new uint256[](0),
            maxOwnerChanges: parent.certificateSpecific.maxOwnerChanges,
            ownerChangeCounter: parent.certificateSpecific.ownerChangeCounter
        });

        _childIdOne = createCertificate( 
            childOneEntity,
            certificateSpecificOne
        );

        TradableEntity memory childTwoEntity = TradableEntity({
            assetId: parent.tradableEntity.assetId,
            owner: parent.tradableEntity.owner,
            powerInW: parent.tradableEntity.powerInW - _power,
            acceptedToken: 0x0,
            onChainDirectPurchasePrice: 0,
            escrow: parent.tradableEntity.escrow,
            approvedAddress: parent.tradableEntity.approvedAddress
        });

        CertificateSpecific memory certificateSpecificTwo = CertificateSpecific({
            retired: false,
            dataLog: parent.certificateSpecific.dataLog,
            creationTime: parent.certificateSpecific.creationTime,
            parentId: _parentId,
            children: new uint256[](0),
            maxOwnerChanges: parent.certificateSpecific.maxOwnerChanges,
            ownerChangeCounter: parent.certificateSpecific.ownerChangeCounter
        });

        _childIdTwo = createCertificate( 
            childTwoEntity,
            certificateSpecificTwo
        );
        addChildren(_parentId, _childIdOne);
        addChildren(_parentId, _childIdTwo);

    }    

	/// @notice function to get the amount of all certificates
	/// @return the amount of all certificates
    function getCertificateListLength() public onlyOwner view returns (uint) {
        return certificateList.length;
    }  

	/// @notice gets a tradable entity
	/// @param _entityId the entity Id
	/// @return the TradableEntity struct
    function getTradableEntity(uint _entityId) public view returns (TradableEntity){
        require(msg.sender == owner || msg.sender == address(this));
        return certificateList[_entityId].tradableEntity;
    }

	/// @notice gets the tradable entity internally as storage
	/// @dev implements an abstract function
	/// @param _entityId the entity Id
	/// @return the TradableEntity as storage
    function getTradableEntityInternally(uint _entityId) internal view returns (TradableEntity storage _entity) {
        require(msg.sender == owner || msg.sender == address(this));
        return certificateList[_entityId].tradableEntity;
    }

	/// @notice sets the TradableEntity
	/// @param _entityId the entity Id
	/// @param _entity the new TradableEntity
    function setTradableEntity(uint _entityId, TradableEntity _entity) public  {
        require(msg.sender == owner || msg.sender == address(this));

        certificateList[_entityId].tradableEntity = _entity;
    }

	/// @notice gets the CertificateSpecific-struct
	/// @param _certificateId the certificate Id
	/// @return the CertificateSpecific-struct
    function getCertificateSpecific(uint _certificateId) 
        external 
        view 
        returns (CertificateSpecificContract.CertificateSpecific _certificate)
    {
        require(msg.sender == owner || msg.sender == address(this));
        return certificateList[_certificateId].certificateSpecific;
    }

	/// @notice gets the CertificateSpecific-struct internally as storage
    /// @dev implements an abstract function
	/// @param _certificateId the certificate Id
	/// @return the CertificateSpecific-struct as storage-pointer
    function getCertificateInternally(uint _certificateId) internal view returns (CertificateSpecificContract.CertificateSpecific storage _certificate){
        return certificateList[_certificateId].certificateSpecific;
    }

	/// @notice sets the CertificateSpecific-struct
	/// @param _certificateId the certificate Id
	/// @param _certificate the new CertificateSpecific-struct
    function setCertificateSpecific(uint _certificateId, CertificateSpecificContract.CertificateSpecific  _certificate) public {
        require(msg.sender == owner || msg.sender == address(this));
        certificateList[_certificateId].certificateSpecific = _certificate;
    }

}