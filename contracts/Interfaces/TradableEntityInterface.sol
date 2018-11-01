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

pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

interface TradableEntityInterface {

	/// @notice set Tradable Token
	/// @param _entityId the entity Id
	/// @param _tokenContract the token Contract
    function setTradableToken(uint _entityId, address _tokenContract) external;
    function setOnChainDirectPurchasePrice(uint _entityId, uint _price) external;
    function getTradableToken(uint _entityId) external view returns (address);
    function getOnChainDirectPurchasePrice(uint _entityId) external view returns (uint);
 //   function getTradableEntity(uint _entityId) external view returns (uint _assetId, address _owner, uint _powerInW, address _acceptedToken, uint _onChainDirectPurchasePrice);
    function supportsInterface(bytes4 _interfaceID) external view returns (bool);
}