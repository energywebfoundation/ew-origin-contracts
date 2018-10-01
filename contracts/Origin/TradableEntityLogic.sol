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
import "../../contracts/Interfaces/ERC20Interface.sol";
import "../../contracts/Interfaces/OriginContractLookupInterface.sol";
import "ew-asset-registry-contracts/Interfaces/AssetContractLookupInterface.sol";

/// @title Contract for storing the current logic-contracts-addresses for the certificate of origin
contract TradableEntityLogic is Updatable, RoleManagement, ERC721, ERC165 {

    EnergyInterface public db;
    OriginContractLookupInterface public originContractLookup;
    AssetContractLookupInterface public assetContractLookup;

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    modifier isInitialized {
        require(address(db) != 0x0, "contract is not yet initialized");
        _;
    }

    modifier onlyEntityOwner(uint _entityId) {
        require(db.getTradableEntity(_entityId).owner == msg.sender, "not the entityOwner");
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

    function balanceOf(address _owner) isInitialized external view returns (uint256){
        require(_owner != 0x0, "zero address not supported!");
        return db.getBalanceOf(_owner);
    }

    function ownerOf(uint256 _entityId) isInitialized external view returns (address){
        address owner = db.getTradableEntity(_entityId).owner;
        require(owner != 0x0, "zero address not supported!");
        return owner;
    }

    function safeTransferFrom(address _from, address _to, uint256 _entityId, bytes _data) isInitialized external payable {
        simpleTransferInternal(_from, _to, _entityId);
        safeTransferChecks(_from, _to, _entityId, _data);
    }

    function safeTransferFrom(address _from, address _to, uint256 _entityId) isInitialized external payable {
        bytes memory data = "";
        simpleTransferInternal(_from, _to, _entityId);
        safeTransferChecks(_from, _to, _entityId, data);
    }

    function transferFrom(address _from, address _to, uint256 _entityId) isInitialized external payable {
        simpleTransferInternal(_from, _to, _entityId);
    }

    function approve(address _approved, uint256 _entityId) isInitialized external payable {
        TradableEntityContract.TradableEntity memory te = db.getTradableEntity(_entityId);
        require(te.owner == msg.sender || checkMatcher(te.escrow),"approve: not the owner or escrow addresss");
        db.addApproval(_entityId, _approved);

        emit Approval(msg.sender,_approved, _entityId);
    }


    function setApprovalForAll(address _escrow, bool _approved) isInitialized external {
        db.setOwnerToOperators(msg.sender, _escrow, _approved);
    }

    function getApproved(uint _tokenId) isInitialized external view returns (address) {
        return db.getApproved(_tokenId);
    }

    function isApprovedForAll(address _company, address _escrow) isInitialized external view returns (bool) {
        return db.getOwnerToOperators(_company, _escrow);
    }

     /**
        external non erc721 functions
     

    function createTradableEntity(
        uint _assetId, 
        address _owner, 
        uint _powerInW, 
        address _acceptedToken, 
        uint _onChainDirectPurchasePrice
    ) 
        isInitialized
        onlyRole(RoleManagement.Role.Trader) 
        external 
        returns (uint tradableEntityId)
    {
        tradableEntityId = EnergyDB(db).createTradableEntityEntry(_assetId, _owner, _powerInW, _acceptedToken, _onChainDirectPurchasePrice);
        
        AssetProducingRegistryDB.Asset memory asset = AssetProducingRegistryLogic(address(cooContract.assetProducingRegistry())).getFullAsset(_assetId);

        EnergyDB(db).setEscrow(tradableEntityId, asset.matcher);
        
        emit Transfer(0, _owner, tradableEntityId);

    }
 */
    /// @notice Initialises the contract by binding it to a logic contract
    /// @param _database Sets the logic contract
    function init(address _database, address _admin) external onlyOwner {
        require(db == EnergyInterface(0x0),"0x0 address as db is not supported");
        db = EnergyInterface(_database);
    }

    function setTradableEntityOwner(uint _entityId, address _owner) onlyEntityOwner(_entityId) userHasRole(Role.Trader, _owner) isInitialized external {
        db.setTradableEntityOwner(_entityId, _owner);
    }

    function setTradableToken(uint _entityId, address _tokenContract) 
        onlyEntityOwner(_entityId) 
        isInitialized external 
    {
        db.setTradableToken(_entityId, _tokenContract);
    }

    function setOnChainDirectPurchasePrice(uint _entityId, uint _price) onlyEntityOwner(_entityId) isInitialized external {
        db.setOnChainDirectPurchasePrice(_entityId, _price);
    }

    /// @notice Updates the logic contract
    /// @param _newLogic Address of the new logic contract
    function update(address _newLogic) 
        isInitialized 
        external
        onlyOwner    
    {
        db.changeOwner(_newLogic);
    }

    function getTradableToken(uint _entityId) isInitialized external view returns (address){
        return db.getTradableToken(_entityId);
    }

    function getOnChainDirectPurchasePrice(uint _entityId) isInitialized external view returns (uint) {
        return db.getOnChainDirectPurchasePrice(_entityId);
    }

    function getTradableEntity(uint _entityId) 
        isInitialized 
        external view 
    returns (
        uint _assetId, 
        address _owner, 
        uint _powerInW, 
        address _acceptedToken, 
        uint _onChainDirectPurchasePrice) 
    {
        TradableEntityContract.TradableEntity memory entity = db.getTradableEntity(_entityId);
        
        _assetId = entity.assetId;
        _owner = entity.owner;
        _powerInW = entity.powerInW;
        _acceptedToken = entity.acceptedToken;
        _onChainDirectPurchasePrice = entity.onChainDirectPurchasePrice;
    }

    function supportsInterface(bytes4 _interfaceID) isInitialized external view returns (bool){
        if(_interfaceID == 0x80ac58cd) return true;
    }

      /// @notice Checks if the msg.sender is included in the matcher-array
    function checkMatcher(address[] _matcher) isInitialized public view returns (bool){

        // we iterate through the matcherarray, the length is defined by the maxMatcherPerAsset-parameter of the Coo-contract or the array-length if it's shorter
        for(uint i = 0; i < (originContractLookup.maxMatcherPerAsset() < _matcher.length? originContractLookup.maxMatcherPerAsset():_matcher.length); i++){
            if(_matcher[i] == msg.sender) return true;
        }
    }

    /// returns the code for a given address
    function getCodeAt(address _addr) internal view returns (bytes o_code) {
        assembly {
            // retrieve the size of the code, this needs assembly
            let size := extcodesize(_addr)
            // allocate output byte array - this could also be done without assembly
            // by using o_code = new bytes(size)
            o_code := mload(0x40)
            // new "memory end" including padding
            mstore(0x40, add(o_code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            // store length in memory
            mstore(o_code, size)
            // actually retrieve the code, this needs assembly
            extcodecopy(_addr, add(o_code, 0x20), 0, size)
        }
    }

    function simpleTransferInternal(address _from, address _to, uint256 _entityId) internal {
        TradableEntityContract.TradableEntity memory te = db.getTradableEntity(_entityId);
        require(msg.value == 0, "Tobalaba Ether not supported");
        require(
            te.owner == msg.sender
            || checkMatcher(te.escrow)
            || db.getOwnerToOperators(te.owner, msg.sender)
            || te.approvedAddress == msg.sender,"safeTransferFrom: missing permission"
        );

        require(te.owner == _from, "safeTransferFrom: address is not the owner");
        require(_to != 0x0, "safeTransferFrom: no 0x0 address allowed");
        require(te.owner != 0x0, "safeTransferFrom: NFT is not valid");
        
        db.setTradableEntityOwner(_entityId, _to);
        db.addApproval(_entityId, 0x0);
        emit Transfer(_from,_to,_entityId);
      
    }

    function safeTransferChecks(address _from, address _to, uint256 _entityId, bytes _data) internal {
        require(getCodeAt(_to).length>0,"receiver is not a smart contract!");
        require(ERC721TokenReceiver(_to).onERC721Received(this,_from,_entityId,_data) == bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")),"safeTransferFrom: transfer failed!");
    }

}