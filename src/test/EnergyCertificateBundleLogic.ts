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

        it('should have the right owner', async () => {

            assert.equal(await energyCertificateBundleLogic.owner(), originRegistryContract.web3Contract._address);

        });

        it('should have the lookup-contracts', async () => {

            assert.equal(await energyCertificateBundleLogic.assetContractLookup(), assetRegistryContract.web3Contract._address);
            assert.equal(await energyCertificateBundleLogic.userContractLookup(), userRegistryContract.web3Contract._address);
        });

        it('should the correct DB', async () => {

            assert.equal(await energyCertificateBundleLogic.db(), energyCertificateBundleDB.web3Contract._address);
        });

        it('should have balances of 0', async () => {

            assert.equal(await energyCertificateBundleLogic.balanceOf(accountDeployment), 0);
            assert.equal(await energyCertificateBundleLogic.balanceOf(accountAssetOwner), 0);
            assert.equal(await energyCertificateBundleLogic.balanceOf(accountTrader), 0);

        });

        it('should throw for balance of address 0x0', async () => {

            let failed = false;
            try {
                await energyCertificateBundleLogic.balanceOf('0x0000000000000000000000000000000000000000');
            } catch (ex) {
                failed = true;
            }

            assert.isTrue(failed);
        });

        it('should throw when trying to access a non existing certificate', async () => {
            let failed = false;
            try {
                await energyCertificateBundleLogic.ownerOf(0);
            } catch (ex) {
                failed = true;
            }

            assert.isTrue(failed);
        });

        it('should throw when trying to call safeTransferFrom a non existing certificate', async () => {
            let failed = false;
            try {
                await energyCertificateBundleLogic.safeTransferFrom(accountDeployment, accountTrader, 0, '0x00', { privateKey: privateKeyDeployment });
            } catch (ex) {
                failed = true;
            }

            assert.isTrue(failed);
        });

        it('should throw when trying to call safeTransferFrom a non existing certificate', async () => {
            let failed = false;
            try {
                await energyCertificateBundleLogic.safeTransferFrom(accountDeployment, accountTrader, 0, { privateKey: privateKeyDeployment });
            } catch (ex) {
                failed = true;
            }

            assert.isTrue(failed);
        });

        it('should throw when trying to call transferFrom a non existing certificate', async () => {
            let failed = false;
            try {
                await energyCertificateBundleLogic.transferFrom(accountDeployment, accountTrader, 0, { privateKey: privateKeyDeployment });
            } catch (ex) {
                failed = true;
            }

            assert.isTrue(failed);
        });

        it('should throw when trying to call approve a non existing certificate', async () => {
            let failed = false;
            try {
                await energyCertificateBundleLogic.approve(accountTrader, 0, { privateKey: privateKeyDeployment });
            } catch (ex) {
                failed = true;
            }

            assert.isTrue(failed);
        });

        it('should set right roles to users', async () => {
            await userLogic.setUser(accountTrader, 'trader', { privateKey: privateKeyDeployment });
            await userLogic.setUser(accountAssetOwner, 'assetOwner', { privateKey: privateKeyDeployment });
            //   await userLogic.setUser(testreceiver.web3Contract._address, 'testreceiver', { privateKey: privateKeyDeployment });

            //    await userLogic.setRoles(testreceiver.web3Contract._address, 16, { privateKey: privateKeyDeployment });
            await userLogic.setRoles(accountTrader, 16, { privateKey: privateKeyDeployment });
            await userLogic.setRoles(accountAssetOwner, 24, { privateKey: privateKeyDeployment });
        });

        it('should onboard an asset', async () => {

            await assetRegistry.createAsset(assetSmartmeter,
                                            accountAssetOwner,
                                            2,
                                            '0x1000000000000000000000000000000000000005',
                                            true,
                                            'propertiesDocuementHash',
                                            'url',
                                            { privateKey: privateKeyDeployment });
        });

        it('should set MarketLogicAddress', async () => {

            await assetRegistry.setMarketLookupContract(0, originRegistryContract.web3Contract._address, { privateKey: assetOwnerPK });

            assert.equal(await assetRegistry.getMarketLookupContract(0), originRegistryContract.web3Contract._address);
        });

        it('should return right interface', async () => {

            assert.isTrue(await energyCertificateBundleLogic.supportsInterface('0x80ac58cd'));
            assert.isFalse(await energyCertificateBundleLogic.supportsInterface('0x80ac58c1'));

        });

        describe('transferFrom', () => {

            it('should have 0 certificates', async () => {
                assert.equal(await energyCertificateBundleLogic.getBundleListLength(), 0);
            });

            it('should log energy', async () => {

                const tx = await assetRegistry.saveSmartMeterReadBundle(
                    0,
                    100,
                    false,
                    'lastSmartMeterReadFileHash',
                    100,
                    false,
                    { privateKey: assetSmartmeterPK });

                const event = (await assetRegistry.getAllLogNewMeterReadEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber }))[0];

                assert.equal(event.event, 'LogNewMeterRead');
                assert.deepEqual(event.returnValues, {
                    0: '0',
                    1: '0',
                    2: '100',
                    3: false,
                    4: '0',
                    5: '0',
                    6: '100',
                    7: false,
                    _assetId: '0',
                    _oldMeterRead: '0',
                    _newMeterRead: '100',
                    _smartMeterDown: false,
                    _certificatesCreatedForWh: '0',
                    _oldCO2OffsetReading: '0',
                    _newCO2OffsetReading: '100',
                    _serviceDown: false,
                });

                if (isGanache) {
                    const allTransferEvents = await energyCertificateBundleLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '0',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '0',
                    });
                }
            });

            it('should have 1 certificate', async () => {
                assert.equal(await energyCertificateBundleLogic.getBundleListLength(), 1);
            });

            it('should return the bundle', async () => {
                const bundle = await energyCertificateBundleLogic.getBundle(0);

                const bundleSpecific = bundle.certificateSpecific;

                assert.isFalse(bundleSpecific.retired);
                assert.equal(bundleSpecific.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(bundleSpecific.coSaved, 100);
                assert.equal(bundleSpecific.parentId, 0);
                assert.equal(bundleSpecific.children.length, 0);
                assert.equal(bundleSpecific.maxOwnerChanges, 2);
                assert.equal(bundleSpecific.ownerChangeCounter, 0);

                const tradableEntity = bundle.tradableEntity;

                assert.equal(tradableEntity.assetId, 0);
                assert.equal(tradableEntity.owner, accountAssetOwner);
                assert.equal(tradableEntity.powerInW, 100);
                assert.equal(tradableEntity.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntity.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntity.escrow, ['0x1000000000000000000000000000000000000005']);
                assert.equal(tradableEntity.approvedAddress, '0x0000000000000000000000000000000000000000');

            });

            it('should have a balance of 1 for assetOwner address', async () => {

                assert.equal(await energyCertificateBundleLogic.balanceOf(accountAssetOwner), 1);

            });

            it('should return the correct owner', async () => {

                assert.equal(await energyCertificateBundleLogic.ownerOf(0), accountAssetOwner);

            });

            it('should return correct approvedFor', async () => {

                assert.equal(await energyCertificateBundleLogic.getApproved(0), '0x0000000000000000000000000000000000000000');

            });

            it('should return correct isApprovedForAll', async () => {

                assert.isFalse(await energyCertificateBundleLogic.isApprovedForAll(accountAssetOwner, accountDeployment));
                assert.isFalse(await energyCertificateBundleLogic.isApprovedForAll(accountAssetOwner, accountTrader));

            });

        });

    });
});