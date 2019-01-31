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
// @authors: slock.it GmbH, Martin Kuechler, martin.kuechler@slock.it

pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;

interface TradableEntityDBInterface {
    function addApprovalExternal(uint _entityId, address _approve) external;
    function addEscrowForEntity(uint _entityId, address _escrow) external;
    function setTradableEntityOwnerExternal(uint _entityId, address _owner) external;
    function setTradableToken(uint _entityId, address _token) external;
    function setOnChainDirectPurchasePrice(uint _entityId, uint _price) external;
    function removeTokenAndPrice(uint _entityId) external;
    function removeEscrow(uint _entityId, address _escrow) external returns (bool);    
    function setOwnerToOperators(address _company, address _escrow, bool _allowed) external;
    function setTradableEntityOwnerAndAddApproval(uint _entityId, address _owner, address _approve) external;
    function setTradableEntityEscrowExternal(uint _entityId, address[] calldata _escrow) external;

    function getApproved(uint256 _entityId) external view returns (address);
    function getBalanceOf(address _owner) external view returns (uint);
    function getTradableToken(uint _entityId) external view returns (address);
    function getTradableEntityOwner(uint _entityId) external view returns (address);
    function getTradableEntityEscrowLength(uint _entityId) external view returns (uint);
    function getOnChainDirectPurchasePrice(uint _entityId) external view returns (uint);
    function getOwnerToOperators(address _company, address _escrow) external view returns (bool);
    
}