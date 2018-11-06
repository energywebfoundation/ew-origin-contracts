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

pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

/// @title The Database contract for the Certificate of Origin list
/// @notice This contract only provides getter and setter methods

import "../../contracts/Origin/TradableEntityContract.sol";
import "ew-utils-general-contracts/contracts/Msc/Owned.sol";
import "../../contracts/Origin/TradableEntityDB.sol";

contract EnergyDB is TradableEntityDB, TradableEntityContract {

    struct Energy {
        TradableEntity tradableEntity;
    }

    /// @notice An array containing all created certificates
    Energy[] private energyList;
    mapping(address => uint) private tokenAmountMapping;
    mapping(address => mapping (address => bool)) ownerToOperators;
    
    /// @notice Constructor
    /// @param _energyLogic The address of the corresbonding logic contract
    constructor(address _energyLogic) TradableEntityDB(_energyLogic) public { }

    /**
        external functions
    */

	/// @notice Adds a new escrow address to an existing certificate
	/// @param _entityId the entity Id
	/// @param _escrow The new escrow-address
    function addEscrowForAsset(uint _entityId, address _escrow) external onlyOwner {
        energyList[_entityId].tradableEntity.escrow.push(_escrow);
    }

	/// @notice sets a new escrow-array for a tradableEnttity
	/// @param _entityId the entity Id
	/// @param _escrow the escrow
    function setEscrow(uint _entityId, address[] _escrow) external onlyOwner {
        energyList[_entityId].tradableEntity.escrow = _escrow;
    }

	/// @notice sets  the ownerToTperators flag
	/// @param _company the company 
	/// @param _escrow the escrow
	/// @param _allowed the allowed-flag
    function setOwnerToOperators(address _company, address _escrow, bool _allowed) external onlyOwner {
        ownerToOperators[_company][_escrow] = _allowed;
    }

	/// @notice creates a TradableEntity entry
	/// @param _assetId the asset Id
	/// @param _owner the owner of the TradableEntity
	/// @param _powerInW the power In W
	/// @param _acceptedToken the accepted token
	/// @param _onChainDirectPurchasePrice the onchain direct purchase price
    function createTradableEntityEntry(  
        uint _assetId, 
        address _owner, 
        uint _powerInW, 
        address _acceptedToken,
        uint _onChainDirectPurchasePrice
    ) 
    external onlyOwner returns (uint _entityId){

        TradableEntity memory te = TradableEntity({
            assetId: _assetId,
            owner: _owner,
            powerInW: _powerInW,
            acceptedToken: _acceptedToken,
            onChainDirectPurchasePrice: _onChainDirectPurchasePrice,
            escrow: new address[](0),
            approvedAddress: 0x0
        }); 
        energyList.push(Energy({tradableEntity: te}));
        _entityId = energyList.length>0?energyList.length-1:0;        
        tokenAmountMapping[_owner]++;
    } 

	/// @notice set a TradableEntity owner and adds an approval-flag
	/// @param _entityId the entity Id
	/// @param _owner the new owner
	/// @param _approve the approve-flag
    function setTradableEntityOwnerAndAddApproval(uint _entityId, address _owner, address _approve) external onlyOwner{
        setTradableEntityOwner(_entityId, _owner);
        addApproval(_entityId, _approve);
    }

	/// @notice sets the tradable token for an entity
	/// @param _entityId the entity Id
	/// @param _token the token-contract-address
    function setTradableToken(uint _entityId, address _token) external onlyOwner {
        energyList[_entityId].tradableEntity.acceptedToken = _token;
    }

	/// @notice sets the onchain direct purchase price
	/// @param _entityId the entity Id
	/// @param _price the price
    function setOnChainDirectPurchasePrice(uint _entityId, uint _price) external onlyOwner {
        energyList[_entityId].tradableEntity.onChainDirectPurchasePrice = _price;
    }

	/// @notice gets the approved address
	/// @param _entityId the entity Id
	/// @return the approved address
    function getApproved(uint256 _entityId) onlyOwner external view returns (address){
        return energyList[_entityId].tradableEntity.approvedAddress;
    }

	/// @notice gets the balance of an account
	/// @param _owner account
	/// @return the balance
    function getBalanceOf(address _owner) external onlyOwner view returns (uint){
        return tokenAmountMapping[_owner];
    }

	/// @notice gets the tradable-token address
	/// @param _entityId the entity Id
	/// @return the tradable-token
    function getTradableToken(uint _entityId) external onlyOwner view returns (address){
        return energyList[_entityId].tradableEntity.acceptedToken;
    }

	/// @notice gets the onchain direct purchase price
	/// @param _entityId the entity Id
	/// @return the onhcain direct purchase price
    function getOnChainDirectPurchasePrice(uint _entityId) onlyOwner external view returns (uint){
        return energyList[_entityId].tradableEntity.onChainDirectPurchasePrice;
    }

	/// @notice get the TradableEntity-struct
	/// @param _entityId the entity Id
	/// @return the TradableEntity-struct
    function getTradableEntity(uint _entityId) onlyOwner public view returns (TradableEntityContract.TradableEntity _entity){
        return energyList[_entityId].tradableEntity;
    }

	/// @notice gets the TradableEntity owner
	/// @param _entityId the entity Id
	/// @return the owner
    function getTradableEntityOwner(uint _entityId) 
        external
        onlyOwner
        view 
        returns (address)
    {
        return energyList[_entityId].tradableEntity.owner;
    }

	/// @notice get whether there is a flag for in ownerToOperators for that escrow account
	/// @param _company the company
	/// @param _escrow the escrow
	/// @return whether there is a flag
    function getOwnerToOperators(address _company, address _escrow) onlyOwner external view returns (bool){
        return ownerToOperators[_company][_escrow];
    }

    /** 
    public functions
     */

	/// @notice sets the TradableEntity owner
	/// @param _entityId the entity Id
	/// @param _owner the new owner
    function setTradableEntityOwner(uint _entityId, address _owner) public onlyOwner {

        assert(tokenAmountMapping[energyList[_entityId].tradableEntity.owner]>0);
        tokenAmountMapping[energyList[_entityId].tradableEntity.owner]--;
        energyList[_entityId].tradableEntity.owner = _owner;
        tokenAmountMapping[energyList[_entityId].tradableEntity.owner]++;

    }

	/// @notice approves an address
	/// @param _entityId the entity Id
	/// @param _approve the approved address
    function addApproval(uint _entityId, address _approve) public onlyOwner {
        energyList[_entityId].tradableEntity.approvedAddress = _approve;
    }
}