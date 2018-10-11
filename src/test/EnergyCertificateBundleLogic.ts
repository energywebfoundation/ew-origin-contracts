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

import { assert } from 'chai';
import * as fs from 'fs';
import 'mocha';
import { Web3Type } from '../types/web3';
import { migrateUserRegistryContracts, UserLogic, UserContractLookup } from 'ew-user-registry-contracts';
import { migrateAssetRegistryContracts, AssetContractLookup, AssetProducingRegistryLogic } from 'ew-asset-registry-contracts';
import { migrateEnergyBundleContracts } from '../utils/migrateContracts';
import { OriginContractLookup } from '../wrappedContracts/OriginContractLookup';
import { CertificateDB } from '../wrappedContracts/CertificateDB';
import { CertificateLogic } from '../wrappedContracts/CertificateLogic';
import { getClientVersion, Sloffle } from 'sloffle';
import { TestReceiver } from '../wrappedContracts/TestReceiver';
import { EnergyCertificateBundleLogic } from '../wrappedContracts/EnergyCertificateBundleLogic';
import { EnergyCertificateBundleDB } from '../wrappedContracts/EnergyCertificateBundleDB';

describe('EnergyCertificateBundleLogic', () => {

    let assetRegistryContract: AssetContractLookup;
    let originRegistryContract: OriginContractLookup;
    let energyCertificateBundleLogic: EnergyCertificateBundleLogic;
    let energyCertificateBundleDB: EnergyCertificateBundleDB;
    let isGanache: boolean;
    let userRegistryContract: UserContractLookup;
    let assetRegistry: AssetProducingRegistryLogic;
    let userLogic: UserLogic;
    let testreceiver: TestReceiver;

    const configFile = JSON.parse(fs.readFileSync(process.cwd() + '/connection-config.json', 'utf8'));

    const Web3 = require('web3');
    const web3: Web3Type = new Web3(configFile.develop.web3);

    const privateKeyDeployment = configFile.develop.deployKey.startsWith('0x') ?
        configFile.develop.deployKey : '0x' + configFile.develop.deployKey;

    const accountDeployment = web3.eth.accounts.privateKeyToAccount(privateKeyDeployment).address;

    const assetOwnerPK = '0xc118b0425221384fe0cbbd093b2a81b1b65d0330810e0792c7059e518cea5383';
    const accountAssetOwner = web3.eth.accounts.privateKeyToAccount(assetOwnerPK).address;

    const traderPK = '0x2dc5120c26df339dbd9861a0f39a79d87e0638d30fdedc938861beac77bbd3f5';
    const accountTrader = web3.eth.accounts.privateKeyToAccount(traderPK).address;

    const assetSmartmeterPK = '0x2dc5120c26df339dbd9861a0f39a79d87e0638d30fdedc938861beac77bbd3f5';
    const assetSmartmeter = web3.eth.accounts.privateKeyToAccount(assetSmartmeterPK).address;

    const matcherPK = '0xd9d5e7a2ebebbad1eb22a63baa739a6c6a6f15d07fcc990ea4dea5c64022a87a';
    const matcherAccount = web3.eth.accounts.privateKeyToAccount(matcherPK).address;

    const approvedPK = '0x7da67da863672d4cc2984e93ce28d98b0d782d8caa43cd1c977b919c0209541b';
    const approvedAccount = web3.eth.accounts.privateKeyToAccount(approvedPK).address;

    describe('init checks', () => {

        it('should deploy the contracts', async () => {

            isGanache = (await getClientVersion(web3)).includes('EthereumJS');

            const userContracts = await migrateUserRegistryContracts(web3);

            userLogic = new UserLogic((web3 as any),
                userContracts[process.cwd() + '/node_modules/ew-user-registry-contracts/dist/contracts/UserLogic.json']);

            await userLogic.setUser(accountDeployment, 'admin', { privateKey: privateKeyDeployment });

            await userLogic.setRoles(accountDeployment, 3, { privateKey: privateKeyDeployment });

            const userContractLookupAddr = userContracts[process.cwd() + '/node_modules/ew-user-registry-contracts/dist/contracts/UserContractLookup.json'];

            userRegistryContract = new UserContractLookup((web3 as any), userContractLookupAddr);
            const assetContracts = await migrateAssetRegistryContracts(web3, userContractLookupAddr);

            const assetRegistryLookupAddr = assetContracts[process.cwd() + '/node_modules/ew-asset-registry-contracts/dist/contracts/AssetContractLookup.json'];

            const assetProducingAddr = assetContracts[process.cwd() + '/node_modules/ew-asset-registry-contracts/dist/contracts/AssetProducingRegistryLogic.json'];
            const originContracts = await migrateEnergyBundleContracts(web3, assetRegistryLookupAddr);

            assetRegistryContract = new AssetContractLookup((web3 as any), assetRegistryLookupAddr);
            originRegistryContract = new OriginContractLookup((web3 as any));
            energyCertificateBundleLogic = new EnergyCertificateBundleLogic((web3 as any));
            energyCertificateBundleDB = new EnergyCertificateBundleDB((web3 as any));
            assetRegistry = new AssetProducingRegistryLogic((web3 as any), assetProducingAddr);

            Object.keys(originContracts).forEach(async (key) => {

                const deployedBytecode = await web3.eth.getCode(originContracts[key]);
                assert.isTrue(deployedBytecode.length > 0);

                const contractInfo = JSON.parse(fs.readFileSync(key, 'utf8'));

                const tempBytecode = '0x' + contractInfo.deployedBytecode;
                assert.equal(deployedBytecode, tempBytecode);

            });
        });


    });
});