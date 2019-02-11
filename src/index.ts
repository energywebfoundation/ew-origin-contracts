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
// @authors: slock.it GmbH; Martin Kuechler, martin.kuchler@slock.it; Heiko Burkhardt, heiko.burkhardt@slock.it;

export { migrateCertificateRegistryContracts, migrateEnergyBundleContracts } from './utils/migrateContracts';
export { CertificateLogic } from './wrappedContracts/CertificateLogic';
export { EnergyCertificateBundleLogic } from './wrappedContracts/EnergyCertificateBundleLogic';
export { TradableEntityLogic } from './wrappedContracts/TradableEntityLogic';
export { EnergyLogic } from './wrappedContracts/EnergyLogic';
export { OriginContractLookup } from './wrappedContracts/OriginContractLookup';

import CertificateDBJSON from '../contract-build/CertificateDB.json';
import CertificateLogicJSON from '../contract-build/CertificateLogic.json';
import CertificateSpecificContractJSON from '../contract-build/CertificateSpecificContract.json';
import CertificateSpecificDBJSON from '../contract-build/CertificateSpecificDB.json';
import EnergyCertificateBundleDBJSON from '../contract-build/EnergyCertificateBundleDB.json';
import EnergyCertificateBundleLogicJSON from '../contract-build/EnergyCertificateBundleLogic.json';
import EnergyDBJSON from '../contract-build/EnergyDB.json';
import EnergyLogicJSON from '../contract-build/EnergyLogic.json';
import OriginContractLookupJSON from '../contract-build/OriginContractLookup.json';
import TradableEntityContractJSON from '../contract-build/TradableEntityContract.json';
import TradableEntityDBJSON from '../contract-build/TradableEntityDB.json';
import TradableEntityLogicJSON from '../contract-build/TradableEntityLogic.json';

export {
    CertificateDBJSON,
    CertificateLogicJSON,
    CertificateSpecificContractJSON,
    CertificateSpecificDBJSON,
    EnergyCertificateBundleDBJSON,
    EnergyCertificateBundleLogicJSON,
    EnergyDBJSON,
    EnergyLogicJSON,
    OriginContractLookupJSON,
    TradableEntityContractJSON,
    TradableEntityDBJSON,
    TradableEntityLogicJSON,
};
