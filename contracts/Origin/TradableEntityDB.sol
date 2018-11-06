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

import "ew-utils-general-contracts/contracts/Msc/Owned.sol";
import "../../contracts/Interfaces/TradableEntityDBInterface.sol";
import "../../contracts/Origin/TradableEntityContract.sol";

contract TradableEntityDB is Owned,TradableEntityDBInterface {

    mapping(address => uint) internal tokenAmountMapping;
    mapping(address => mapping (address => bool)) internal ownerToOperators;

    /// @notice Constructor
    constructor(address _certificateLogic) Owned(_certificateLogic) public { }
    
    /**
        abstract functions
     */
	/// @notice gets a TradableEntity-struct
	/// @param _entityId the entity Id
	/// @return the TradableEntity
    function getTradableEntity(uint _entityId) public view returns (TradableEntityContract.TradableEntity _entity);

	/// @notice gets a TradableEntity-struct as storage pointer
	/// @param _entityId the entity Id
	/// @return the the TradableEntity-struct as storage pointer
    function getTradableEntityInternally(uint _entityId) internal view returns (TradableEntityContract.TradableEntity storage _entity);
	
    /// @notice set a TradableEntity
	/// @param _entityId the entity Id
	/// @param _entity the new TradableEntity
    function setTradableEntity(uint _entityId, TradableEntityContract.TradableEntity _entity) public;
    
    /**
     */

	/// @notice changes a TradableEntity owner
	/// @param _old the old owner
	/// @param _new the new owner
    function changeCertOwner(address _old, address _new) internal {
        require(tokenAmountMapping[_old] > 0,"not enough token");
        tokenAmountMapping[_old]--;
        tokenAmountMapping[_new]++;
    }
    
	/// @notice gets the balance of an account
	/// @param _owner the owner
	/// @return the balance
    function getBalanceOf(address _owner) external onlyOwner view returns (uint){
        return tokenAmountMapping[_owner];
    }

	/// @notice set owner to operators mapping
	/// @param _company the company
	/// @param _escrow the escrow
	/// @param _allowed the allowance-flag
    function setOwnerToOperators(address _company, address _escrow, bool _allowed) external onlyOwner {
        ownerToOperators[_company][_escrow] = _allowed;
    }

	/// @notice gets an entry of the owner to operators mapping
	/// @param _company the company
	/// @param _escrow the escrow
	/// @return the allowance-flag
    function getOwnerToOperators(address _company, address _escrow) onlyOwner external view returns (bool){
        return ownerToOperators[_company][_escrow];
    }


	/// @notice adds an approved address
	/// @param _entityId the entity Id
	/// @param _approve the approved address
    function addApproval(uint _entityId, address _approve) public onlyOwner {
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        te.approvedAddress = _approve;
    }

	/// @notice adds an escrow-address for entity
	/// @param _entityId the entity Id
	/// @param _escrow the escrow-address
    function addEscrowForEntity(uint _entityId, address _escrow) external onlyOwner {
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        te.escrow.push(_escrow);
    }

	/// @notice sets the owner of a certificate
	/// @param _entityId The array position in which the certificate is stored
	/// @param _owner The address of the new owner
    function setTradableEntityOwner(uint _entityId, address _owner) public onlyOwner {
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        address oldOwner = te.owner;
        te.owner = _owner;
        changeCertOwner(oldOwner,_owner);

    }

	/// @notice sets a tradable token
	/// @param _entityId the entity Id
	/// @param _token the tradable-token address
    function setTradableToken(uint _entityId, address _token) external onlyOwner {
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        te.acceptedToken = _token;
    }

	/// @notice sets the escrow-addresses of a certificate
	/// @param _entityId the entity Id
	/// @param _escrow new escrow-addresses
    function setTradableEntityEscrow(uint _entityId, address[] _escrow)
        public
        onlyOwner
    {
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        te.escrow = _escrow;
    }

	/// @notice sets an onchain direct purchase price
	/// @param _entityId the entity Id
	/// @param _price the price
    function setOnChainDirectPurchasePrice(uint _entityId, uint _price) external onlyOwner {
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        te.onChainDirectPurchasePrice = _price;
    }

	/// @notice removes token and price of an entity
    /// @dev should be used after transfering a TradableEntity 
	/// @param _entityId the entity Id
    function removeTokenAndPrice(uint _entityId) external onlyOwner {
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        te.onChainDirectPurchasePrice = 0;
        te.acceptedToken = 0;
    }

	/// @notice Removes an escrow-address of an existing bundle
	/// @param _entityId The array position
	/// @param _escrow the escrow-address to be removed
	/// @return whether that address was removed
    function removeEscrow(uint _entityId, address _escrow) external onlyOwner returns (bool) {

        address[] storage escrows = getTradableEntityInternally(_entityId).escrow;
        for (uint i = 0; i < escrows.length; i++){
            if(escrows[i] == _escrow){
                escrows[i] = escrows[escrows.length-1];
                escrows.length--;
                return true;
            }
        }
    }

	/// @notice gets the approved address for an entity
	/// @param _entityId the entity Id
	/// @return the approved address
    function getApproved(uint256 _entityId) onlyOwner external view returns (address){
        return getTradableEntity(_entityId).approvedAddress;
    }

	/// @notice gets the onchain direct purchase price
	/// @param _entityId the entity Id
	/// @return the onchain direct purchase price
    function getOnChainDirectPurchasePrice(uint _entityId) external onlyOwner view returns (uint){
        return getTradableEntity(_entityId).onChainDirectPurchasePrice;
    }

	/// @notice gets the tradable token
	/// @param _entityId the entity Id
	/// @return the tradable token
    function getTradableToken(uint _entityId) external onlyOwner view returns (address) {
        return getTradableEntity(_entityId).acceptedToken;
    }

	/// @notice gets the TradableEntity owner
	/// @param _entityId the entity Id
	/// @return the TradableEntity owner
    function getTradableEntityOwner(uint _entityId) external onlyOwner view returns (address){
        return getTradableEntity(_entityId).owner;
    }
    
	/// @notice gets the TradableEntity escrow length
	/// @param _entityId the entity Id
	/// @return the TradableEntity-owner
    function getTradableEntityEscrowLength(uint _entityId) external onlyOwner view returns (uint){
        return getTradableEntity(_entityId).escrow.length;
    }

	/// @notice sets the TradableEntity owner and an approved address
	/// @param _entityId the entity Id
	/// @param _owner the owner
	/// @param _approve the approve address
    function setTradableEntityOwnerAndAddApproval(uint _entityId, address _owner, address _approve) external onlyOwner {
        setTradableEntityOwner(_entityId, _owner);
        addApproval(_entityId, _approve);
    }

}