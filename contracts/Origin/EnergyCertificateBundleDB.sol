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
import "../../contracts/Origin/CertificateDB.sol";
import "../../contracts/Origin/TradableEntityDB.sol";
import "../../contracts/Origin/CertificateSpecificContract.sol";
import "../../contracts/Origin/CertificateSpecificDB.sol";

contract EnergyCertificateBundleDB is TradableEntityDB, TradableEntityContract, CertificateSpecificContract, CertificateSpecificDB {

    struct EnergyCertificateBundle {
        TradableEntity tradableEntity;
        CertificateSpecific certificateSpecific;
    }

    /// @notice An array containing all created bundles
    EnergyCertificateBundle[] private bundleList;

    /// @notice Constructor
    constructor(address _certificateLogic) TradableEntityDB(_certificateLogic) public { }

    /**
        external functions
    */

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

    function getTradableEntityInternally(uint _entityId) internal view returns (TradableEntityContract.TradableEntity storage _entity) {
        require(msg.sender == owner || msg.sender == address(this));
        return bundleList[_entityId].tradableEntity;
    }

    function setTradableEntity(uint _entityId, TradableEntityContract.TradableEntity _entity) public  {
        require(msg.sender == owner || msg.sender == address(this));
        bundleList[_entityId].tradableEntity = _entity;
    }

    function getCertificateSpecific(uint _certificateId) 
        external 
        view 
        returns (CertificateSpecificContract.CertificateSpecific _certificate)
    {
        require(msg.sender == owner || msg.sender == address(this));
        return bundleList[_certificateId].certificateSpecific;
    }

    function getCertificateInternally(uint _certificateId) internal view returns (CertificateSpecificContract.CertificateSpecific  storage _certificate){
        return bundleList[_certificateId].certificateSpecific;
    }
    function setCertificateSpecific(uint _certificateId, CertificateSpecificContract.CertificateSpecific  _certificate) public {
        require(msg.sender == owner || msg.sender == address(this));
        bundleList[_certificateId].certificateSpecific = _certificate;
    }
}