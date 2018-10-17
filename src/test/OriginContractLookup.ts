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
import { migrateUserRegistryContracts, UserLogic } from 'ew-user-registry-contracts';
import { migrateAssetRegistryContracts, AssetContractLookup } from 'ew-asset-registry-contracts';
import { migrateCertificateRegistryContracts } from '../utils/migrateContracts';
import { OriginContractLookup } from '../wrappedContracts/OriginContractLookup';
import { CertificateDB } from '../wrappedContracts/CertificateDB';
import { CertificateLogic } from '../wrappedContracts/CertificateLogic';
import { getClientVersion } from 'sloffle';

describe('OriginContractLookup', () => {

    const configFile = JSON.parse(fs.readFileSync(process.cwd() + '/connection-config.json', 'utf8'));

    const Web3 = require('web3');
    const web3: Web3Type = new Web3(configFile.develop.web3);

    const privateKeyDeployment = configFile.develop.deployKey.startsWith('0x') ?
        configFile.develop.deployKey : '0x' + configFile.develop.deployKey;

    const accountDeployment = web3.eth.accounts.privateKeyToAccount(privateKeyDeployment).address;

    let assetRegistryContract: AssetContractLookup;
    let originRegistryContract: OriginContractLookup;
    let certificateLogic: CertificateLogic;
    let certificateDB: CertificateDB;
    let isGanache: boolean;

    it('should deploy the contracts', async () => {

        isGanache = (await getClientVersion(web3)).includes('EthereumJS');

        const userContracts = await migrateUserRegistryContracts(web3);

        const userLogic = new UserLogic((web3 as any),
            userContracts[process.cwd() + '/node_modules/ew-user-registry-contracts/dist/contracts/UserLogic.json']);

        await userLogic.setUser(accountDeployment, 'admin', { privateKey: privateKeyDeployment });

        await userLogic.setRoles(accountDeployment, 3, { privateKey: privateKeyDeployment });

        const userContractLookupAddr = userContracts[process.cwd() + '/node_modules/ew-user-registry-contracts/dist/contracts/UserContractLookup.json'];

        const assetContracts = await migrateAssetRegistryContracts(web3, userContractLookupAddr);

        const assetRegistryLookupAddr = assetContracts[process.cwd() + '/node_modules/ew-asset-registry-contracts/dist/contracts/AssetContractLookup.json'];

        const originContracts = await migrateCertificateRegistryContracts(web3, assetRegistryLookupAddr);

        assetRegistryContract = new AssetContractLookup((web3 as any), assetRegistryLookupAddr);
        originRegistryContract = new OriginContractLookup((web3 as any));
        certificateLogic = new CertificateLogic((web3 as any));
        certificateDB = new CertificateDB((web3 as any));
        Object.keys(originContracts).forEach(async (key) => {

            const deployedBytecode = await web3.eth.getCode(originContracts[key]);
            assert.isTrue(deployedBytecode.length > 0);

            const contractInfo = JSON.parse(fs.readFileSync(key, 'utf8'));

            const tempBytecode = '0x' + contractInfo.deployedBytecode;
            assert.equal(deployedBytecode, tempBytecode);

        });
    });

    it('should have the right owner', async () => {

        assert.equal(await originRegistryContract.owner(), accountDeployment);

    });

    it('should have the right registries', async () => {

        assert.equal(await originRegistryContract.originLogicRegistry(), certificateLogic.web3Contract._address);
        assert.equal(await originRegistryContract.assetContractLookup(), assetRegistryContract.web3Contract._address);

    });

    it('should fail when trying to call init again', async () => {
        let failed = false;

        try {
            await originRegistryContract.init(
                '0x1000000000000000000000000000000000000005',
                '0x1000000000000000000000000000000000000005',
                '0x1000000000000000000000000000000000000005',
                { privateKey: privateKeyDeployment });
        }
        catch (ex) {
            failed = true;
        }
        assert.isTrue(failed);
    });

    it('should throw an error when calling update as non Owner', async () => {

        let failed = false;
        try {
            await originRegistryContract.update('0x1000000000000000000000000000000000000005',
                { privateKey: '0x191c4b074672d9eda0ce576cfac79e44e320ffef5e3aadd55e000de57341d36c' });
        }
        catch (ex) {
            failed = true;
        }
        assert.isTrue(failed);
    });

    it('should be able to update as owner', async () => {

        await originRegistryContract.update('0x1000000000000000000000000000000000000005',
            { privateKey: privateKeyDeployment });

        assert.equal(await originRegistryContract.originLogicRegistry(), '0x1000000000000000000000000000000000000005');
        assert.equal(await certificateDB.owner(), '0x1000000000000000000000000000000000000005');

    });

    it('should throw when trying to change owner as non-owner', async () => {

        let failed = false;

        try {
            await originRegistryContract.changeOwner('0x1000000000000000000000000000000000000005',
                { privateKey: '0x191c4b074672d9eda0ce576cfac79e44e320ffef5e3aadd55e000de57341d36c' });
        }
        catch (ex) {
            failed = true;

        }

        assert.isTrue(failed);

    });

    it('should be able to change owner ', async () => {

        await originRegistryContract.changeOwner('0x1000000000000000000000000000000000000005',
            { privateKey: privateKeyDeployment });

        assert.equal(await originRegistryContract.owner(), '0x1000000000000000000000000000000000000005');
    });

});
