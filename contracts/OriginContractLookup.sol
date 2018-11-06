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
// @authors: slock.it GmbH, Martin Kuechler, martin.kuchler@slock.it

pragma solidity ^0.4.24;

import "ew-utils-general-contracts/contracts/Msc/Owned.sol";
import "ew-utils-general-contracts/contracts/Interfaces/Updatable.sol";
import "ew-user-registry-contracts/contracts/Interfaces/UserContractLookupInterface.sol";
import "../contracts/Interfaces/OriginContractLookupInterface.sol";
import "ew-asset-registry-contracts/contracts/Interfaces/AssetContractLookupInterface.sol";

/// @title Contract for storing the current logic-contracts-addresses for the certificate of origin
contract OriginContractLookup is Owned, OriginContractLookupInterface {
    
    Updatable public originLogicRegistry;
    AssetContractLookupInterface public assetContractLookup;

    uint public maxMatcherPerCertificate;

    /// @notice The constructor 
    constructor() Owned(msg.sender) public{ 
        maxMatcherPerCertificate = 10;
    } 

	/// @notice function to initialize the contracts, setting the needed contract-addresses
	/// @param _assetRegistry the asset Registry
	/// @param _originLogicRegistry the origin Logic Registry
	/// @param _originDB the origin DB
    function init(
        AssetContractLookupInterface _assetRegistry, 
        Updatable _originLogicRegistry, 
        address _originDB 
    ) 
        external
        onlyOwner
    {
        require(    
            _assetRegistry != address(0) && _originLogicRegistry != address(0)
            && originLogicRegistry == address(0) && assetContractLookup == address(0) && assetContractLookup == address(0),
            "already initialized"
        );
        require(_originDB != 0, "originDB cannot be 0");

        originLogicRegistry = _originLogicRegistry;
        assetContractLookup = _assetRegistry;

        originLogicRegistry.init(_originDB, msg.sender);
    }

	/// @notice set the amount of maximal matcher per certificate
	/// @param _new the new amount
    function setMaxMatcherPerCertificate(uint _new)
        external 
        onlyOwner 
    {
        maxMatcherPerCertificate = _new;
    }

   
	/// @notice function to update one or more logic-contracts
	/// @param _originRegistry address of the new user-registry-logic-contract
    function update(
        Updatable _originRegistry
    )
        external
        onlyOwner 
    {
        require(address(_originRegistry)!= 0, "update: cannot set to 0");
        originLogicRegistry.update(_originRegistry);
        originLogicRegistry = _originRegistry;
    }

	/// @notice gets the origin logic registry
	/// @return the origin logic registry
    function originLogicRegistry() external view returns (address){
        return originLogicRegistry;
    }

	/// @notice gets the asset contract lookup
	/// @return the asset contract lookup
    function assetContractLookup() external view returns (address){
        return assetContractLookup;
    }

	/// @notice gets the maximal amount of matcher per certificate
	/// @return the maximal amount of matcher per certificate
    function maxMatcherPerCertificate() external view returns (uint){
        return maxMatcherPerCertificate;
    }


}