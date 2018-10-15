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

import "ew-utils-general-contracts/Msc/Owned.sol";
import "../../contracts/Interfaces/TradableEntityDBInterface.sol";
import "../../contracts/Interfaces/EnergyInterface.sol";


contract TradableEntityDB is Owned,TradableEntityDBInterface {

    mapping(address => uint) internal tokenAmountMapping;
    mapping(address => mapping (address => bool)) internal ownerToOperators;

  /// @notice Constructor
    constructor(address _certificateLogic) Owned(_certificateLogic) public { }
    
    function setTradableEntity(uint _entityId, TradableEntityContract.TradableEntity _entity) public;
    function getTradableEntity(uint _entityId) public view returns (TradableEntityContract.TradableEntity _entity);

    function getTradableEntityInternally(uint _entityId) internal view returns (TradableEntityContract.TradableEntity storage _entity);

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


    function addApproval(uint _entityId, address _approve) public onlyOwner {

        TradableEntityContract.TradableEntity memory te  = EnergyInterface(this).getTradableEntity(_entityId);

        te.approvedAddress = _approve;

        EnergyInterface(this).setTradableEntity(_entityId,te);
    }

    /// @notice Sets the owner of a certificate
    /// @param _entityId The array position in which the certificate is stored
    /// @param _owner The address of the new owner
    function setTradableEntityOwner(uint _entityId, address _owner) public onlyOwner {
        TradableEntityContract.TradableEntity memory te = EnergyInterface(this).getTradableEntity(_entityId);
        address oldOwner = te.owner;
        te.owner = _owner;
        changeCertOwner(oldOwner,_owner);
        EnergyInterface(this).setTradableEntity(_entityId,te);

    }

    function setTradableToken(uint _entityId, address _token) external onlyOwner {
        TradableEntityContract.TradableEntity memory te = EnergyInterface(this).getTradableEntity(_entityId);
        te.acceptedToken = _token;
        EnergyInterface(this).setTradableEntity(_entityId,te);
    }

    /// @notice sets the escrow-addresses of a certificate
    /// @param _escrow new escrow-addresses
    function setTradableEntityEscrow(uint _entityId, address[] _escrow)
        public
        onlyOwner
    {
        TradableEntityContract.TradableEntity memory te = EnergyInterface(this).getTradableEntity(_entityId);
        te.escrow = _escrow;
        EnergyInterface(this).setTradableEntity(_entityId,te);

    }

    function setOnChainDirectPurchasePrice(uint _entityId, uint _price) external onlyOwner {
        TradableEntityContract.TradableEntity memory te = EnergyInterface(this).getTradableEntity(_entityId);
        te.onChainDirectPurchasePrice = _price;
        EnergyInterface(this).setTradableEntity(_entityId,te);
    }

    function removeTokenAndPrice(uint _entityId) external onlyOwner {
        TradableEntityContract.TradableEntity memory te = EnergyInterface(this).getTradableEntity(_entityId);
        te.onChainDirectPurchasePrice = 0;
        te.acceptedToken = 0;
        EnergyInterface(this).setTradableEntity(_entityId,te);

    }

    function getApproved(uint256 _entityId) onlyOwner external view returns (address){
        return EnergyInterface(this).getTradableEntity(_entityId).approvedAddress;
    }

    function getOnChainDirectPurchasePrice(uint _entityId) external onlyOwner view returns (uint){
        return EnergyInterface(this).getTradableEntity(_entityId).onChainDirectPurchasePrice;
    }

    function getTradableToken(uint _entityId) external onlyOwner view returns (address) {
        return EnergyInterface(this).getTradableEntity(_entityId).acceptedToken;
    }

    function getTradableEntityOwner(uint _entityId) external onlyOwner view returns (address){
        return EnergyInterface(this).getTradableEntity(_entityId).owner;
    }
    
    function getTradableEntityEscrowLength(uint _entityId) external onlyOwner view returns (uint){
        return EnergyInterface(this).getTradableEntity(_entityId).escrow.length;
    }

    function setTradableEntityOwnerAndAddApproval(uint _entityId, address _owner, address _approve) external onlyOwner {
        setTradableEntityOwner(_entityId, _owner);
        addApproval(_entityId, _approve);
    }

}