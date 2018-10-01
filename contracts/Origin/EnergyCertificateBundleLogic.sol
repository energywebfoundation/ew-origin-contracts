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
import "../../contracts/Interfaces/ERC20Interface.sol";
import "../../contracts/Origin/TradableEntityLogic.sol";
import "../../contracts/Origin/EnergyCertificateBundleDB.sol";
import "../../contracts/Interfaces/OriginContractLookupInterface.sol";
import "ew-asset-registry-contracts/Interfaces/AssetContractLookupInterface.sol";


contract EnergyCertificateBundleLogic is RoleManagement, TradableEntityLogic  {

    /// @notice Logs the creation of an event
    event LogCreatedBundle(uint indexed _bundleId, uint powerInW, address owner);
    /// @notice Logs the request of an retirement of a bundle
    event LogBundleRetired(uint indexed _bundleId, bool _retire);
    event LogBundleOwnerChanged(uint indexed _bundleId, address _oldOwner, address _newOwner, address _oldEscrow);
    event LogEscrowRemoved(uint indexed _bundleId, address _escrow);
    event LogEscrowAdded(uint indexed _bundleId, address _escrow);
    
    AssetContractLookupInterface public assetContractLookup;

    /// @notice Checks if the contract is initialized
    modifier isInitialized() {
        require(EnergyCertificateBundleDB(db) != EnergyCertificateBundleDB(0x0),"logic not initialized");
        _;
    }
    
   /// @notice Constructor
    constructor(
        AssetContractLookupInterface _assetContractLookup,
        OriginContractLookupInterface _originContractLookup
    )
        TradableEntityLogic(_assetContractLookup, _originContractLookup) 
    public {
        assetContractLookup = _assetContractLookup;
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
        isInitialized 
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
        isInitialized 
        onlyRole(RoleManagement.Role.Trader) 
        external payable 
    {
        bytes memory data = "";
        internalSafeTransfer(_from, _to, _entityId, data);
    }

    function transferFrom(address _from, address _to, uint256 _entityId) isInitialized external payable {
        EnergyCertificateBundleDB.EnergyCertificateBundle memory bundle = EnergyCertificateBundleDB(db).getBundle(_entityId);
        simpleTransferInternal(_from, _to, _entityId);
        emit LogBundleOwnerChanged(_entityId, bundle.tradableEntity.owner, _to, 0x0);
        checktransferOwnerInternally(_entityId, bundle);
    }


    /**
        external functions
    */

    /// @notice adds a new escrow address to a bundle
    /// @param _bundleId The id of the bundle
    /// @param _escrow The additional escrow address
    function addEscrowForAsset(uint _bundleId, address _escrow) external isInitialized(){
        EnergyCertificateBundleDB.EnergyCertificateBundle memory bundle = EnergyCertificateBundleDB(db).getBundle(_bundleId);
        require(bundle.tradableEntity.owner == msg.sender,"addEscrowForAsset: wrong account");
        require(bundle.tradableEntity.escrow.length < originContractLookup.maxMatcherPerAsset(), "current matcher limit reached");
        db.addEscrowForAsset(_bundleId, _escrow);
        emit LogEscrowAdded(_bundleId, _escrow);
    }
 
    /// @notice Request a bundle to retire. Only bundle owner can retire
    /// @param _bundleId The id of the bundle
    function retireBundle(uint _bundleId) external isInitialized() {
        EnergyCertificateBundleDB.EnergyCertificateBundle memory bundle = EnergyCertificateBundleDB(db).getBundle(_bundleId);
        require(bundle.tradableEntity.owner == msg.sender, "retire: wrong sender");
        require(bundle.certificateSpecific.children.length == 0,"retire: bundle was splitted");
        if (!bundle.certificateSpecific.retired) {
            retireBundleAuto(_bundleId);
        }
    }

    /// @notice Removes an escrow-address of a bundle
    /// @param _bundleId The id of the bundl
    /// @param _escrow The address to be removed
    function removeEscrow(uint _bundleId, address _escrow) external isInitialized() {
        require(EnergyCertificateBundleDB(db).getBundle(_bundleId).tradableEntity.owner == msg.sender,"removeEscrow: wrong account");
        require(EnergyCertificateBundleDB(db).removeEscrow(_bundleId, _escrow),"removeEscrow: address not found");
        emit LogEscrowRemoved(_bundleId, _escrow);
    }

    /// @notice function to allow an escrow-address to change the ownership of a bundle
    /// @dev this function can only be called by the demandLogic
    /// @param _bundleId the bundle-id
    /// @param _newOwner the new owner of the bundle
    function transferOwnershipByEscrow(uint _bundleId, address _newOwner) 
        external 
        isInitialized 
    {   
        EnergyCertificateBundleDB.EnergyCertificateBundle memory bundle = EnergyCertificateBundleDB(db).getBundle(_bundleId);
        require (checkMatcher(bundle.tradableEntity.escrow),"transferEscrow: account not an escrow for that bundle");
        
        emit LogBundleOwnerChanged(_bundleId, bundle.tradableEntity.owner, _newOwner, msg.sender);
        simpleTransferInternal(bundle.tradableEntity.owner,_newOwner, _bundleId);
        checktransferOwnerInternally(_bundleId, bundle);


    }

    /// @notice Getter for a specific Bundle
    /// @param _bundleId The id of the requested bundle
    /// @return the bundle as single values
    function getBundle(uint _bundleId) external view 
        returns (  
            uint _assetId, 
            address _owner,
            uint _powerInW,
            bool _retired,
            string _dataLog,
            uint _coSaved,
            address[] _escrow,
            uint _creationTime, 
            uint _parentId,
            uint[] _children,
            uint _maxOwnerChanges,
            uint _ownerChangeCounter)
        {
        EnergyCertificateBundleDB.EnergyCertificateBundle memory bundle = EnergyCertificateBundleDB(db).getBundle(_bundleId);
        _assetId = bundle.tradableEntity.assetId;
        _owner = bundle.tradableEntity.owner;
        _powerInW = bundle.tradableEntity.powerInW;
        _retired = bundle.certificateSpecific.retired;
        _dataLog = bundle.certificateSpecific.dataLog;
        _coSaved = bundle.certificateSpecific.coSaved;
        _escrow = bundle.tradableEntity.escrow;
        _creationTime = bundle.certificateSpecific.creationTime;
        _parentId = bundle.certificateSpecific.parentId;
        _children = bundle.certificateSpecific.children;
        _maxOwnerChanges = bundle.certificateSpecific.maxOwnerChanges;
        _ownerChangeCounter = bundle.certificateSpecific.ownerChangeCounter;
    }

    /// @notice Getter for the length of the list of bundles
    /// @return the length of the array
    function getBundleListLength() external view returns (uint) {
        return EnergyCertificateBundleDB(db).getBundleListLength();
    }

    /// @notice Getter for a specific bundle
    /// @param _bundleId The id of the requested bundle
    /// @return the bundle as single values
    function getBundleOwner(uint _bundleId) external view returns (address) {
        return EnergyCertificateBundleDB(db).getBundle(_bundleId).tradableEntity.owner;
    }

    /// @notice Getter for a specific bundle
    /// @param _bundleId The id of the requested bundle
    /// @return the bundle as single values
    function isRetired(uint _bundleId) external view returns (bool) {
        return EnergyCertificateBundleDB(db).getBundle(_bundleId).certificateSpecific.retired;
    }

    /**
        public functions
    */

    /// @notice Creates a bundle. Checks in the AssetRegistry if requested wh are available.
    /// @param _assetId The id of the asset that generated the energy for the bundle 
    /// @param _powerInW The amount of Watts the bundle holds
    /// @param _cO2Saved The amount of CO2 saved
    /// @param _escrow The escrow-addresses
    function createBundle(uint _assetId, uint _powerInW, uint _cO2Saved, address[] _escrow) 
        public 
        isInitialized 
        onlyAccount(address(assetContractLookup.assetProducingRegistry()))
        returns (uint) 
    {
        AssetProducingRegistryDB.Asset memory asset = AssetProducingInterface(address(assetContractLookup.assetProducingRegistry())).getFullAsset(_assetId);

        TradableEntityContract.TradableEntity memory tradableEntity = TradableEntityContract.TradableEntity({
            assetId: _assetId,
            owner: asset.owner,
            powerInW: _powerInW,
            acceptedToken: 0x0,
            onChainDirectPurchasePrice: 0,
            escrow: _escrow,
            approvedAddress: 0x0

        });

        CertificateDB.CertificateSpecific memory certificateSpecific = CertificateDB.CertificateSpecific({
            retired: false,
            dataLog: asset.lastSmartMeterReadFileHash,
            coSaved: _cO2Saved,
            creationTime: block.timestamp,
            parentId: EnergyCertificateBundleDB(db).getBundleListLength(),
            children: new uint256[](0),
            maxOwnerChanges: asset.maxOwnerChanges,
            ownerChangeCounter: 0
        });
            
        uint bundleId = EnergyCertificateBundleDB(db).createEnergyCertificateBundle(
            tradableEntity,  
            certificateSpecific
        );

        emit Transfer(0,  asset.owner, bundleId);

        emit LogCreatedBundle(bundleId, _powerInW, asset.owner);
        return bundleId;
     
    }

    /**
        internal functions
    */

    /// @notice Retires a bundle
    /// @param _bundleId The id of the requested bundle
    function retireBundleAuto(uint _bundleId) internal isInitialized(){
        address[] memory empty; 
        EnergyCertificateBundleDB(db).setBundleEscrow(_bundleId, empty);
        EnergyCertificateBundleDB(db).retireBundle(_bundleId);
        emit LogBundleRetired(_bundleId, true);
    }

    function internalSafeTransfer(
        address _from, 
        address _to, 
        uint256 _entityId, 
        bytes _data
    )
        internal
    {
        EnergyCertificateBundleDB.EnergyCertificateBundle memory bundle = EnergyCertificateBundleDB(db).getBundle(_entityId);
        simpleTransferInternal(_from, _to, _entityId);
        safeTransferChecks(_from, _to, _entityId, _data);
        emit LogBundleOwnerChanged(_entityId, bundle.tradableEntity.owner, _to, 0x0);
        checktransferOwnerInternally(_entityId, bundle);
    }

    /// @notice Transfers the ownership, checks if the requirements are met
    /// @param _bundleId The id of the requested bundle
    /// @param _bundle The bundle where the ownership should be transfered
    function checktransferOwnerInternally(uint _bundleId, EnergyCertificateBundleDB.EnergyCertificateBundle _bundle) internal {
        require(_bundle.certificateSpecific.children.length == 0,"transferEscrow: bundle already splitted");
        require(!_bundle.certificateSpecific.retired,"transferEscrow: bundle already retired");
        require(_bundle.certificateSpecific.ownerChangeCounter < _bundle.certificateSpecific.maxOwnerChanges, "transferEscrow: maximum amount of ownerChanges reached");
        uint ownerChangeCounter = _bundle.certificateSpecific.ownerChangeCounter + 1;
        address[] memory empty; 

        EnergyCertificateBundleDB(db).setOwnerChangeCounter(_bundleId, ownerChangeCounter);
        EnergyCertificateBundleDB(db).setBundleEscrow(_bundleId, empty);

        if(_bundle.certificateSpecific.maxOwnerChanges <= ownerChangeCounter){
            EnergyCertificateBundleDB(db).setBundleEscrow(_bundleId, empty);
            EnergyCertificateBundleDB(db).retireBundle(_bundleId);
            emit LogBundleRetired(_bundleId, true);
        }
    }
}