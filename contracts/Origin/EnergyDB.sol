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
    /// @param _escrow The new escrow-address
    function addEscrowForAsset(uint _entityId, address _escrow) external onlyOwner {
        energyList[_entityId].tradableEntity.escrow.push(_escrow);
    }

    function setEscrow(uint _entityId, address[] _escrow) external onlyOwner {
        energyList[_entityId].tradableEntity.escrow = _escrow;
    }

    function setOwnerToOperators(address _company, address _escrow, bool _allowed) external onlyOwner {
        ownerToOperators[_company][_escrow] = _allowed;
    }

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

   

    function setTradableEntityOwnerAndAddApproval(uint _entityId, address _owner, address _approve) external onlyOwner{
        setTradableEntityOwner(_entityId, _owner);
        addApproval(_entityId, _approve);
    }

    function setTradableToken(uint _entityId, address _token) external onlyOwner {
        energyList[_entityId].tradableEntity.acceptedToken = _token;
    }

    function setOnChainDirectPurchasePrice(uint _entityId, uint _price) external onlyOwner {
        energyList[_entityId].tradableEntity.onChainDirectPurchasePrice = _price;
    }

    function getApproved(uint256 _entityId) onlyOwner external view returns (address){
        return energyList[_entityId].tradableEntity.approvedAddress;
    }

    function getBalanceOf(address _owner) external onlyOwner view returns (uint){
        return tokenAmountMapping[_owner];
    }

    function getTradableToken(uint _entityId) external onlyOwner view returns (address){
        return energyList[_entityId].tradableEntity.acceptedToken;
    }

    function getOnChainDirectPurchasePrice(uint _entityId) onlyOwner external view returns (uint){
        return energyList[_entityId].tradableEntity.onChainDirectPurchasePrice;
    }

    function getTradableEntity(uint _entityId) onlyOwner public view returns (TradableEntityContract.TradableEntity _entity){
        return energyList[_entityId].tradableEntity;
    }

    function getTradableEntityOwner(uint _entityId) 
        external
        onlyOwner
        view 
        returns (address)
    {
        return energyList[_entityId].tradableEntity.owner;
    }

    function getOwnerToOperators(address _company, address _escrow) onlyOwner external view returns (bool){
        return ownerToOperators[_company][_escrow];
    }

    /** 
    public functions
     */

    function setTradableEntityOwner(uint _entityId, address _owner) public onlyOwner {

        assert(tokenAmountMapping[energyList[_entityId].tradableEntity.owner]>0);
        tokenAmountMapping[energyList[_entityId].tradableEntity.owner]--;
        energyList[_entityId].tradableEntity.owner = _owner;
        tokenAmountMapping[energyList[_entityId].tradableEntity.owner]++;

    }

    function addApproval(uint _entityId, address _approve) public onlyOwner {
        energyList[_entityId].tradableEntity.approvedAddress = _approve;
    }
}