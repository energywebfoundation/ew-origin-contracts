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

pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

interface CertificateSpecificDBInterface {
    function getRetired(uint _certificateID) external returns (bool);
    function setRetired(uint _certificateID, bool _retired) external; 
    
    function getDataLog(uint _certificateID) external returns (string memory);
    function setDataLog(uint _certificateID, string calldata _newDataLog) external;

    function getMaxOwnerChanges(uint _certificateID) external returns (uint);
    function setMaxOwnerChanges(uint _certificateID, uint _newMaxOwnerChanges) external;

    function getOwnerChangeCounter(uint _certificateID) external returns (uint);
    function setOwnerChangeCounter(uint _certificateID, uint _newOwnerChangeCounter) external;

    function getCertificateChildrenLength(uint _certificateID) external view returns (uint);
	/// @notice add Children
	/// @param _certificateId the certificate Id
	/// @param _childId the child Id
    function addChildrenExternal(uint _certificateId, uint _childId) external;
}