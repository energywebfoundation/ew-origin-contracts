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

pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "ew-utils-general-contracts/contracts/Msc/Owned.sol";
import "../../contracts/Interfaces/TradableEntityDBInterface.sol";
import "../../contracts/Origin/TradableEntityContract.sol";

contract TradableEntityDB is Owned,TradableEntityDBInterface {

    mapping(address => uint) internal tokenAmountMapping;
    mapping(address => mapping (address => bool)) internal ownerToOperators;

  /// @notice Constructor
    constructor(address _certificateLogic) Owned(_certificateLogic) public { }
    
    function getTradableEntity(uint _entityId) public view returns (TradableEntityContract.TradableEntity memory _entity);

    function getTradableEntityInternally(uint _entityId) internal view returns (TradableEntityContract.TradableEntity storage _entity);
    function setTradableEntity(uint _entityId, TradableEntityContract.TradableEntity memory _entity) public;
    
    function changeCertOwner(address _old, address _new) internal {
        require(tokenAmountMapping[_old] > 0);
        tokenAmountMapping[_old]--;
        tokenAmountMapping[_new]++;
    }
    
    function getBalanceOf(address _owner) external onlyOwner view returns (uint){
        return tokenAmountMapping[_owner];
    }

    function setOwnerToOperators(address _company, address _escrow, bool _allowed) external onlyOwner {
        ownerToOperators[_company][_escrow] = _allowed;
    }

    function getOwnerToOperators(address _company, address _escrow) onlyOwner external view returns (bool){
        return ownerToOperators[_company][_escrow];
    }


    function addApproval(uint _entityId, address _approve) public {

        require(msg.sender == owner || msg.sender == address(this),"not the owner or contract");
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        te.approvedAddress = _approve;
    }

    function addApprovalExternal(uint _entityId, address _approve) external onlyOwner {
        addApproval(_entityId, _approve);
    }


    function addEscrowForEntity(uint _entityId, address _escrow) external onlyOwner {
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        te.escrow.push(_escrow);
    }

    /// @notice Sets the owner of a certificate
    /// @param _entityId The array position in which the certificate is stored
    /// @param _owner The address of the new owner
    function setTradableEntityOwner(uint _entityId, address _owner) public {
        require(msg.sender == owner || msg.sender == address(this),"not the owner or contract");
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        address oldOwner = te.owner;
        te.owner = _owner;
        changeCertOwner(oldOwner,_owner);

    }

    function setTradableEntityOwnerExternal(uint _entityId, address _owner) external onlyOwner {
        setTradableEntityOwner(_entityId, _owner);
    }

    function setTradableToken(uint _entityId, address _token) external onlyOwner {
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        te.acceptedToken = _token;
    }

    function setTradableEntityEscrowExternal(uint _entityId, address[] calldata _escrow) external onlyOwner {
        setTradableEntityEscrow(_entityId, _escrow);
    }

    /// @notice sets the escrow-addresses of a certificate
    /// @param _escrow new escrow-addresses
    function setTradableEntityEscrow(uint _entityId, address[] memory _escrow)
        public
    {
        require(msg.sender == owner || msg.sender == address(this),"not the owner or contract");
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        te.escrow = _escrow;
    }

    function setOnChainDirectPurchasePrice(uint _entityId, uint _price) external onlyOwner {
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        te.onChainDirectPurchasePrice = _price;
    }

    function removeTokenAndPrice(uint _entityId) external onlyOwner {
        TradableEntityContract.TradableEntity storage te = getTradableEntityInternally(_entityId);
        te.onChainDirectPurchasePrice = 0;
        te.acceptedToken = address(0);
    }

    /// @notice Removes an escrow-address of an existing bundle
    /// @param _entityId The array position
    /// @param _escrow the escrow-address to be removed
    function removeEscrow(uint _entityId, address _escrow) external onlyOwner  returns (bool) {

        address[] storage escrows = getTradableEntityInternally(_entityId).escrow;
        for (uint i = 0; i < escrows.length; i++){
            if(escrows[i] == _escrow){
                escrows[i] = escrows[escrows.length-1];
                escrows.length--;
                return true;
            }
        }
    }

    function getApproved(uint256 _entityId) onlyOwner external view returns (address){
        return getTradableEntity(_entityId).approvedAddress;
    }

    function getOnChainDirectPurchasePrice(uint _entityId) external onlyOwner view returns (uint){
        return getTradableEntity(_entityId).onChainDirectPurchasePrice;
    }

    function getTradableToken(uint _entityId) external onlyOwner view returns (address) {
        return getTradableEntity(_entityId).acceptedToken;
    }

    function getTradableEntityOwner(uint _entityId) external onlyOwner view returns (address){
        return getTradableEntity(_entityId).owner;
    }
    
    function getTradableEntityEscrowLength(uint _entityId) external onlyOwner view returns (uint){
        return getTradableEntity(_entityId).escrow.length;
    }

    function setTradableEntityOwnerAndAddApproval(uint _entityId, address _owner, address _approve) external onlyOwner {
        setTradableEntityOwner(_entityId, _owner);
        addApproval(_entityId, _approve);
    }

}