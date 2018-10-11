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
import "../../contracts/Origin/CertificateDB.sol";

contract EnergyCertificateBundleDB is EnergyInterface, Owned, TradableEntityContract {

    struct EnergyCertificateBundle {
        TradableEntity tradableEntity;
        CertificateDB.CertificateSpecific certificateSpecific;

    }

    /// @notice An array containing all created bundles
    EnergyCertificateBundle[] private bundleList;
    mapping(address => uint) private tokenAmountMapping;
    mapping(address => mapping (address => bool)) ownerToOperators;

    /// @notice Constructor
    /// @param _bundleLogic The address of the corresbonding logic contract
    constructor(address _bundleLogic) Owned(_bundleLogic) public { }

    /**
        external functions
    */
    function addApproval(uint _entityId, address _approve) public onlyOwner {
        bundleList[_entityId].tradableEntity.approvedAddress = _approve;
    }

    /// @notice Adds a new escrow address to an existing bundle
    /// @param _escrow The new escrow-address
    function addEscrowForAsset(uint _entityId, address _escrow) external onlyOwner {
        bundleList[_entityId].tradableEntity.escrow.push(_escrow);
    }

    /// @notice sets the escrow-addresses of a bundle
    /// @param _bundleId the id of the bundle
    /// @param _escrow new escrow-addresses
    function setBundleEscrow(uint _bundleId, address[] _escrow)
        external
        onlyOwner
    {
        bundleList[_bundleId].tradableEntity.escrow = _escrow;
    }

    /// @notice Sets the owner of a bundle
    /// @param _entityId The array position in which the bundle is stored
    /// @param _owner The address of the new owner
    function setTradableEntityOwner(uint _entityId, address _owner) public onlyOwner {
        bundleList[_entityId].tradableEntity.owner = _owner;
    }

    function setTradableToken(uint _entityId, address _token) external onlyOwner {
        bundleList[_entityId].tradableEntity.acceptedToken = _token;
    }

    function setOnChainDirectPurchasePrice(uint _entityId, uint _price) external onlyOwner {
        bundleList[_entityId].tradableEntity.onChainDirectPurchasePrice = _price;
    }

    /// @notice Changes the OwnerChangeCounter of an existing bundle
    /// @param _bundleId The array position in which the parent certificate is stored
    function setOwnerChangeCounter(uint _bundleId, uint _newCounter) external onlyOwner {
        EnergyCertificateBundle storage certificate = bundleList[_bundleId];
        certificate.certificateSpecific.ownerChangeCounter = _newCounter;
    }

    function setOwnerToOperators(address _company, address _escrow, bool _allowed) external onlyOwner {
        ownerToOperators[_company][_escrow] = _allowed;
    }

    /// @notice Removes an escrow-address of an existing bundle
    /// @param _bundleId The array position in which the parent certificate is stored
    /// @param _escrow the escrow-address to be removed
    function removeEscrow(uint _bundleId, address _escrow) external onlyOwner  returns (bool) {

        address[] storage escrows = bundleList[_bundleId].tradableEntity.escrow;
        for (uint i = 0; i < escrows.length; i++){
            if(escrows[i] == _escrow){
                escrows[i] = escrows[escrows.length-1];
                escrows.length--;
                return true;
            }
        }
    }

    /// @notice Sets a bundle to retired
    /// @param _bundleId The array position in which the bundle is stored
    function retireBundle(uint _bundleId) external onlyOwner{
     
        EnergyCertificateBundle storage bundle = bundleList[_bundleId];
        bundle.certificateSpecific.retired = true;
    }


    function getApproved(uint256 _entityId) onlyOwner external view returns (address){
        return bundleList[_entityId].tradableEntity.approvedAddress;
    }

    function getBalanceOf(address _owner) external onlyOwner view returns (uint){
        return tokenAmountMapping[_owner];
    }
    

    /// @notice Returns the certificate that corresponds to the given array id
    /// @param _bundleID The array position in which the certificate is stored
    /// @return Certificate as struct
    function getBundle(uint _bundleID) 
        external 
        onlyOwner
        view 
        returns (EnergyCertificateBundle) 
    {
        return bundleList[_bundleID];
    }

    /// @notice function to get the amount of all bundle
    /// @return the amount of all certificates
    function getBundleListLength() external onlyOwner view returns (uint) {
        return bundleList.length;
    }  

    function getOnChainDirectPurchasePrice(uint _entityId) external view returns (uint){
        return bundleList[_entityId].tradableEntity.onChainDirectPurchasePrice;
    }

    function getOwnerToOperators(address _company, address _escrow) onlyOwner external view returns (bool){
        return ownerToOperators[_company][_escrow];
    }
    function getTradableEntity(uint _entityId) external view returns (TradableEntityContract.TradableEntity _entity){
        return bundleList[_entityId].tradableEntity;
    }

    function getTradableEntityOwner(uint _entityId) external view returns (address){
        return bundleList[_entityId].tradableEntity.owner;
    }
    

    function getTradableToken(uint _entityId) external view returns (address) {
        return bundleList[_entityId].tradableEntity.acceptedToken;
    }

    function setTradableEntityOwnerAndAddApproval(uint _entityId, address _owner, address _approve) external onlyOwner{
        setTradableEntityOwner(_entityId, _owner);
        addApproval(_entityId, _approve);
    }
    /**
        public functions
    */

    /// @notice Creates a new certificate
    /// @param _tradableEntity The tradeable entity specific properties
    /// @param _certificateSpecific The certificate specific properties
    /// @return The id of the certificate
    function createEnergyCertificateBundle(
        TradableEntity _tradableEntity,
        CertificateDB.CertificateSpecific _certificateSpecific 
    ) 
        public 
        onlyOwner 
        returns 
        (uint _certId) 
    {
        _certId = bundleList.push(
            EnergyCertificateBundle(
                _tradableEntity,
                _certificateSpecific
            )
        ) - 1;
    }  
}