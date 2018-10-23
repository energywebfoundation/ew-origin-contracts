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

import "../../contracts/Origin/EnergyCertificateBundleDB.sol";

interface EnergyCertificateBundleInterface {

    function addEscrowForAsset(uint _bundleId, address _escrow) external;
    function retireBundle(uint _bundleId) external;
    function removeEscrow(uint _bundleId, address _escrow) external;
   // function transferOwnershipByEscrow(uint _bundleId, address _newOwner) external;
  //  function getBundle(uint _bundleId) external view returns (uint _assetId, address _owner,uint _powerInW,bool _retired,string _dataLog,uint _coSaved,address[] _escrow,uint _creationTime, uint _parentId,uint[] _children,uint _maxOwnerChanges,uint _ownerChangeCounter);
    
    function getBundle(uint _bundleId) external view returns (EnergyCertificateBundleDB.EnergyCertificateBundle);
    function getBundleListLength() external view returns (uint);
    function getBundleOwner(uint _bundleId) external view returns (address);
    function isRetired(uint _bundleId) external view returns (bool);
    function createBundle(uint _assetId, uint _powerInW) external returns (uint);
}