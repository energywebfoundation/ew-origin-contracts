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
pragma experimental ABIEncoderV2;

import "ew-user-registry-contracts/Users/RoleManagement.sol";
import "ew-utils-general-contracts/Interfaces/Updatable.sol";
import "../../contracts/Origin/TradableEntityContract.sol";
import "../../contracts/Interfaces/EnergyInterface.sol";
import "../../contracts/Interfaces/ERC721.sol";
import "../../contracts/Interfaces/ERC721TokenReceiver.sol";
import "../../contracts/Interfaces/ERC165.sol";
import "ew-asset-registry-contracts/Interfaces/AssetProducingInterface.sol";
import "ew-asset-registry-contracts/Asset/AssetProducingRegistryDB.sol";
import "../../contracts/Origin/EnergyDB.sol";
import "../../contracts/Interfaces/TradableEntityDBInterface.sol";
import "../../contracts/Interfaces/OriginContractLookupInterface.sol";
import "../../contracts/Interfaces/TradableEntityInterface.sol";
import "ew-asset-registry-contracts/Interfaces/AssetContractLookupInterface.sol";
import "ew-user-registry-contracts/Interfaces/UserContractLookupInterface.sol";

/// @title Contract for storing the current logic-contracts-addresses for the certificate of origin
contract TradableEntityLogic is Updatable, RoleManagement, ERC721, ERC165, TradableEntityInterface {

    EnergyInterface public db;
    AssetContractLookupInterface public assetContractLookup;

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    modifier onlyEntityOwner(uint _entityId) {
        require(TradableEntityDBInterface(db).getTradableEntityOwner(_entityId) == msg.sender);
        _;
    }

    constructor(
        AssetContractLookupInterface _assetContractLookup,
        OriginContractLookupInterface _originContractLookup
    ) 
        RoleManagement(UserContractLookupInterface(_assetContractLookup.userRegistry()), _originContractLookup) 
        public 
    {
        assetContractLookup = _assetContractLookup;
    }


    /**
        ERC721 functions
        TODO: token creation: function + transfer-event
     */

    function balanceOf(address _owner) external view returns (uint256){
        require(_owner != 0x0);
        return TradableEntityDBInterface(db).getBalanceOf(_owner);
    }

    function ownerOf(uint256 _entityId) external view returns (address){
        address owner = TradableEntityDBInterface(db).getTradableEntityOwner(_entityId);
        require(owner != 0x0);
        return owner;
    }

    function safeTransferFrom(address _from, address _to, uint256 _entityId, bytes _data) external payable {
        simpleTransferInternal(_from, _to, _entityId);
        safeTransferChecks(_from, _to, _entityId, _data);
    }

    function safeTransferFrom(address _from, address _to, uint256 _entityId) external payable {
        bytes memory data = "";
        simpleTransferInternal(_from, _to, _entityId);
        safeTransferChecks(_from, _to, _entityId, data);
    }

    function transferFrom(address _from, address _to, uint256 _entityId) external payable {
        simpleTransferInternal(_from, _to, _entityId);
    }

    function approve(address _approved, uint256 _entityId) external payable {
        TradableEntityContract.TradableEntity memory te = db.getTradableEntity(_entityId);
        require(te.owner == msg.sender || checkMatcher(te.escrow));
        TradableEntityDBInterface(db).addApproval(_entityId, _approved);

        emit Approval(msg.sender,_approved, _entityId);
    }


    function setApprovalForAll(address _escrow, bool _approved) external {
        TradableEntityDBInterface(db).setOwnerToOperators(msg.sender, _escrow, _approved);
        emit ApprovalForAll(msg.sender, _escrow, _approved);
    }

    function getApproved(uint _tokenId) external view returns (address) {
        return TradableEntityDBInterface(db).getApproved(_tokenId);
    }

    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return TradableEntityDBInterface(db).getOwnerToOperators(_owner, _operator);
    }

     /**
        external non erc721 functions  
    */
    
    /// @notice Initialises the contract by binding it to a logic contract
    /// @param _database Sets the logic contract
    function init(address _database, address _admin) external onlyOwner {
        require(db == EnergyInterface(0x0));
        db = EnergyInterface(_database);
    }

    function setTradableEntityOwner(uint _entityId, address _owner) onlyEntityOwner(_entityId) userHasRole(Role.Trader, _owner) external {
         TradableEntityDBInterface(db).setTradableEntityOwner(_entityId, _owner);
    }

    function setTradableToken(uint _entityId, address _tokenContract) 
        onlyEntityOwner(_entityId) 
        external 
    {
        TradableEntityDBInterface(db).setTradableToken(_entityId, _tokenContract);
    }

    function setOnChainDirectPurchasePrice(uint _entityId, uint _price) onlyEntityOwner(_entityId) external {
        TradableEntityDBInterface(db).setOnChainDirectPurchasePrice(_entityId, _price);
    }

    /// @notice Updates the logic contract
    /// @param _newLogic Address of the new logic contract
    function update(address _newLogic) 
        external
        onlyOwner    
    {
        Owned(db).changeOwner(_newLogic);
    }

    function getTradableToken(uint _entityId) external view returns (address){
        return TradableEntityDBInterface(db).getTradableToken(_entityId);
    }

    function getOnChainDirectPurchasePrice(uint _entityId) external view returns (uint) {
        return TradableEntityDBInterface(db).getOnChainDirectPurchasePrice(_entityId);
    }
   
    function getTradableEntity(uint _entityId)  
        external view 
    returns (
       TradableEntityContract.TradableEntity)
    {
        return db.getTradableEntity(_entityId);
    }

    function supportsInterface(bytes4 _interfaceID) external view returns (bool){
        if(_interfaceID == 0x80ac58cd) return true;
    }

      /// @notice Checks if the msg.sender is included in the matcher-array
    function checkMatcher(address[] _matcher) public view returns (bool){

        // we iterate through the matcherarray, the length is defined by the maxMatcherPerAsset-parameter of the Coo-contract or the array-length if it's shorter
        for(uint i = 0; i < ( AssetContractLookupInterface(assetContractLookup).maxMatcherPerAsset() < _matcher.length? AssetContractLookupInterface(assetContractLookup).maxMatcherPerAsset():_matcher.length); i++){
            if(_matcher[i] == msg.sender) return true;
        }
    }

    function isContract(address _address) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(_address) }
        return size > 0;
    }

    function simpleTransferInternal(address _from, address _to, uint256 _entityId) internal {
        TradableEntityContract.TradableEntity memory te = db.getTradableEntity(_entityId);

       
        require(
            (te.owner == _from) &&(_to != 0x0) && (te.owner != 0x0) && (msg.value == 0) && 
            (te.owner == msg.sender
            || checkMatcher(te.escrow)
            || TradableEntityDBInterface(db).getOwnerToOperators(te.owner, msg.sender)
            || te.approvedAddress == msg.sender
        ));
        
        TradableEntityDBInterface(db).setTradableEntityOwnerAndAddApproval(_entityId, _to,0x0);
        emit Transfer(_from,_to,_entityId);
      
    }

    function safeTransferChecks(address _from, address _to, uint256 _entityId, bytes _data) internal {
        require(isContract(_to));
        require(ERC721TokenReceiver(_to).onERC721Received(this,_from,_entityId,_data) == 0x150b7a02);
    }

}