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

import "ew-user-registry-contracts/contracts/Users/RoleManagement.sol";
import "ew-utils-general-contracts/contracts/Interfaces/Updatable.sol";
import "../../contracts/Origin/TradableEntityContract.sol";
import "../../contracts/Interfaces/ERC721.sol";
import "../../contracts/Interfaces/ERC721TokenReceiver.sol";
import "../../contracts/Interfaces/ERC165.sol";
import "ew-asset-registry-contracts/contracts/Interfaces/AssetProducingInterface.sol";
import "../../contracts/Origin/EnergyDB.sol";
import "../../contracts/Interfaces/TradableEntityDBInterface.sol";
import "../../contracts/Interfaces/OriginContractLookupInterface.sol";
import "../../contracts/Interfaces/TradableEntityInterface.sol";
import "ew-asset-registry-contracts/contracts/Interfaces/AssetContractLookupInterface.sol";
import "ew-user-registry-contracts/contracts/Interfaces/UserContractLookupInterface.sol";

/// @title Contract for storing the current logic-contracts-addresses for the certificate of origin
contract TradableEntityLogic is Updatable, RoleManagement, ERC721, ERC165, TradableEntityInterface {

    TradableEntityDBInterface public db;
    AssetContractLookupInterface public assetContractLookup;

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    event LogEscrowRemoved(uint indexed _certificateId, address _escrow);
    event LogEscrowAdded(uint indexed _certificateId, address _escrow);

    modifier onlyEntityOwner(uint _entityId) {
        require(db.getTradableEntityOwner(_entityId) == msg.sender,"not the enitity-owner");
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
	/// @notice gets the balance of an address
	/// @param _owner the address
	/// @return the balance
    function balanceOf(address _owner) external view returns (uint256){
        require(_owner != 0x0,"address 0x0 not allowed");
        return db.getBalanceOf(_owner);
    }

	/// @notice gets the owner of an entity
	/// @param _entityId the entity Id 
	/// @return the owner
    function ownerOf(uint256 _entityId) external view returns (address){
        address owner = db.getTradableEntityOwner(_entityId);
        require(owner != 0x0,"address 0x0 not allowed");
        return owner;
    }

	/// @notice safely transfers an entity to a new owner
	/// @param _from the old owner
	/// @param _to the new owner
	/// @param _entityId the entity Id
	/// @param _data the data
    function safeTransferFrom(address _from, address _to, uint256 _entityId, bytes _data) external payable {
        simpleTransferInternal(_from, _to, _entityId);
        safeTransferChecks(_from, _to, _entityId, _data);
    }

	/// @notice safely transfers an entity to a new owner
	/// @param _from the old owner
	/// @param _to the new owner
	/// @param _entityId the entity Id
    function safeTransferFrom(address _from, address _to, uint256 _entityId) external payable {
        bytes memory data = "";
        simpleTransferInternal(_from, _to, _entityId);
        safeTransferChecks(_from, _to, _entityId, data);
    }

	/// @notice transfers an entity to a new owner
	/// @param _from the old owner
	/// @param _to the new owner
	/// @param _entityId the entity Id
    function transferFrom(address _from, address _to, uint256 _entityId) external payable {
        simpleTransferInternal(_from, _to, _entityId);
    }

	/// @notice approves an address for an entity
	/// @param _approved the approved address
	/// @param _entityId the entity Id
    function approve(address _approved, uint256 _entityId) external payable {
        TradableEntityContract.TradableEntity memory te = TradableEntityDB(db).getTradableEntity(_entityId);
        require(te.owner == msg.sender || checkMatcher(te.escrow),"approve: not owner / matcher");
        db.addApproval(_entityId, _approved);

        emit Approval(msg.sender,_approved, _entityId);
    }


	/// @notice set approval for all entitys of an address
	/// @param _escrow the escrow-address
	/// @param _approved the approved
    function setApprovalForAll(address _escrow, bool _approved) external {
        db.setOwnerToOperators(msg.sender, _escrow, _approved);
        emit ApprovalForAll(msg.sender, _escrow, _approved);
    }

	/// @notice gets the approved address for an entity
	/// @param _entityId the entity Id
	/// @return the approved address
    function getApproved(uint _entityId) external view returns (address) {
        return db.getApproved(_entityId);
    }

	/// @notice gets whether an address is approved for all the owner's entities
	/// @param _owner the owner 
	/// @param _operator the operator
	/// @return whether the operator is approved
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return db.getOwnerToOperators(_owner, _operator);
    }

     /**
        external non erc721 functions  
    */
    
	/// @notice Initialises the contract by binding it to a logic contract
	/// @param _database Sets the logic contract
	/// @param _admin the admin
    function init(address _database, address _admin) external onlyOwner {
        require(db == TradableEntityDBInterface(0x0),"init: 0x0 is not allowd");
        db = TradableEntityDBInterface(_database);
    }


	/// @notice set tradable token
	/// @param _entityId the entity Id
	/// @param _tokenContract the token Contract
    function setTradableToken(uint _entityId, address _tokenContract) 
        onlyEntityOwner(_entityId) 
        external 
    {
        db.setTradableToken(_entityId, _tokenContract);
    }

	/// @notice sets an onchain direct purchase price
	/// @param _entityId the entity Id
	/// @param _price the price
    function setOnChainDirectPurchasePrice(uint _entityId, uint _price) onlyEntityOwner(_entityId) external {
        db.setOnChainDirectPurchasePrice(_entityId, _price);
    }

	/// @notice Updates the logic contract
	/// @param _newLogic Address of the new logic contract
    function update(address _newLogic) 
        external
        onlyOwner    
    {
        Owned(db).changeOwner(_newLogic);
    }

	/// @notice gets the tradable token
	/// @param _entityId the entity Id
	/// @return the tradable token
    function getTradableToken(uint _entityId) external view returns (address){
        return db.getTradableToken(_entityId);
    }

	/// @notice gets the onchain direct purchase price
	/// @param _entityId the entity Id
	/// @return the
    function getOnChainDirectPurchasePrice(uint _entityId) external view returns (uint) {
        return db.getOnChainDirectPurchasePrice(_entityId);
    }
   
	/// @notice gets the TradableEntity
	/// @param _entityId the entity Id
	/// @return the TradableEntity-struct
    function getTradableEntity(uint _entityId)  
        external view 
    returns (
       TradableEntityContract.TradableEntity)
    {
        return TradableEntityDB(db).getTradableEntity(_entityId);
    }

	/// @notice supports interface
	/// @param _interfaceID the interface id
	/// @return true when called with 0x80ac58cd
    function supportsInterface(bytes4 _interfaceID) external view returns (bool){
        if(_interfaceID == 0x80ac58cd) return true;
    }

	/// @notice Checks if the msg.sender is included in the matcher-array
	/// @param _matcher the matcher
	/// @return true if the address is in the matcher-array
    function checkMatcher(address[] _matcher) public view returns (bool){

        // we iterate through the matcherarray, the length is defined by the maxMatcherPerAsset-parameter of the Coo-contract or the array-length if it's shorter
        for(uint i = 0; i < ( AssetContractLookupInterface(assetContractLookup).maxMatcherPerAsset() < _matcher.length? AssetContractLookupInterface(assetContractLookup).maxMatcherPerAsset():_matcher.length); i++){
            if(_matcher[i] == msg.sender) return true;
        }
    }

	/// @notice returns whether that specific address is a contract
	/// @param _address the address
	/// @return true if the address is a contract
    function isContract(address _address) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(_address) }
        return size > 0;
    }

	/// @notice internal ownership-change function
    /// @dev gets called by the safetransfer funcsions
	/// @param _from the old owner
	/// @param _to the new owner
	/// @param _entityId the entity Id
    function simpleTransferInternal(address _from, address _to, uint256 _entityId) internal {
        TradableEntityContract.TradableEntity memory te = TradableEntityDB(db).getTradableEntity(_entityId);

        require(te.owner == _from,"not the owner of the entity");
        require(te.owner != 0x0, "0x0 as owner is not allowed");
        require(msg.value == 0, "sending value is not allowed");
      //  require((te.owner == _from) && (te.owner != 0x0) && (msg.value == 0),"owner not matching or send value");
        require(te.owner == msg.sender
            || checkMatcher(te.escrow)
            || db.getOwnerToOperators(te.owner, msg.sender)
            || te.approvedAddress == msg.sender,"simpleTransfer, missing rights");
        db.setTradableEntityOwnerAndAddApproval(_entityId, _to,0x0);
        db.removeTokenAndPrice(_entityId);
        emit Transfer(_from,_to,_entityId);
      
    }

	/// @notice checks whether receiver is a contract and returns the correct response
	/// @param _from the current owner
	/// @param _to the (contract) address
	/// @param _entityId the entity Id
	/// @param _data the data
    function safeTransferChecks(address _from, address _to, uint256 _entityId, bytes _data) internal {
        require(isContract(_to),"_to is not a contract");
        require(ERC721TokenReceiver(_to).onERC721Received(this,_from,_entityId,_data) == 0x150b7a02,"_to did not respond correctly");
    }

	/// @notice Removes an escrow-address of a certifiacte
	/// @param _certificateId The id of the certificate
	/// @param _escrow The address to be removed
    function removeEscrow(uint _certificateId, address _escrow) external onlyEntityOwner(_certificateId){
  //      require(db.getTradableEntityOwner(_certificateId) == msg.sender);
        require(db.removeEscrow(_certificateId, _escrow),"escrow address not in array");
        emit LogEscrowRemoved(_certificateId, _escrow);
    }

	/// @notice adds a new escrow address to a certificate
	/// @param _certificateId The id of the certificate
	/// @param _escrow The additional escrow address
    function addEscrowForEntity(uint _certificateId, address _escrow) 
        external
        onlyEntityOwner(_certificateId)
    {
        require(db.getTradableEntityEscrowLength(_certificateId) < OriginContractLookupInterface(owner).maxMatcherPerCertificate(),"maximum amount of escrows reached");
        db.addEscrowForEntity(_certificateId, _escrow);
        emit LogEscrowAdded(_certificateId, _escrow);
    }
}