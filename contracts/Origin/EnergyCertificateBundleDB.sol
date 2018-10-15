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
import "../../contracts/Interfaces/EnergyInterface.sol";
import "../../contracts/Origin/EnergyDB.sol";
import "../../contracts/Origin/CertificateDB.sol";
import "../../contracts/Origin/TradableEntityDB.sol";

contract EnergyCertificateBundleDB is TradableEntityDB, EnergyInterface, TradableEntityContract {

    struct EnergyCertificateBundle {
        TradableEntity tradableEntity;
        CertificateDB.CertificateSpecific certificateSpecific;
    }

    /// @notice An array containing all created bundles
    EnergyCertificateBundle[] private bundleList;

    /// @notice Constructor
    constructor(address _certificateLogic) TradableEntityDB(_certificateLogic) public { }

    /**
        external functions
    */

    /// @notice Adds a new escrow address to an existing bundle
    /// @param _escrow The new escrow-address
    function addEscrowForCertificate(uint _entityId, address _escrow) external onlyOwner {
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

    /// @notice Changes the OwnerChangeCounter of an existing bundle
    /// @param _bundleId The array position in which the parent certificate is stored
    function setOwnerChangeCounter(uint _bundleId, uint _newCounter) external onlyOwner {
        EnergyCertificateBundle storage certificate = bundleList[_bundleId];
        certificate.certificateSpecific.ownerChangeCounter = _newCounter;
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

    /// @notice Returns the certificate that corresponds to the given array id
    /// @param _bundleID The array position in which the certificate is stored
    /// @return Certificate as struct
    function getBundle(uint _bundleID) 
        external 
        view 
        returns (EnergyCertificateBundle) 
    {
        require(msg.sender == owner || msg.sender == address(this));
        return bundleList[_bundleID];
    }

    /// @notice function to get the amount of all bundle
    /// @return the amount of all certificates
    function getBundleListLength() external onlyOwner view returns (uint) {
        return bundleList.length;
    }  

    
    function getTradableEntity(uint _entityId) 
        public 
        view 
        returns (TradableEntityContract.TradableEntity _entity)
    {
        require(msg.sender == owner || msg.sender == address(this));
        return bundleList[_entityId].tradableEntity;
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

        tokenAmountMapping[_tradableEntity.owner]++;

    }  


    function setTradableEntity(uint _entityId, TradableEntityContract.TradableEntity _entity) public {
        require(msg.sender == owner || msg.sender == address(this));
        bundleList[_entityId].tradableEntity = _entity;
    }

    function getTradableEntityInternally(uint _entityId) internal view returns (TradableEntityContract.TradableEntity storage _entity) {
        require(msg.sender == owner || msg.sender == address(this));
        return bundleList[_entityId].tradableEntity;
     }
}