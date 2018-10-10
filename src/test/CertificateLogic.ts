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
import { migrateCertificateRegistryContracts } from '../utils/migrateContracts';
import { OriginContractLookup } from '../wrappedContracts/OriginContractLookup';
import { CertificateDB } from '../wrappedContracts/CertificateDB';
import { CertificateLogic } from '../wrappedContracts/CertificateLogic';
import { getClientVersion, Sloffle } from 'sloffle';
import { TestReceiver } from '../wrappedContracts/TestReceiver';

describe('CertificateLogic', () => {

    let assetRegistryContract: AssetContractLookup;
    let originRegistryContract: OriginContractLookup;
    let certificateLogic: CertificateLogic;
    let certificateDB: CertificateDB;
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
            const originContracts = await migrateCertificateRegistryContracts(web3, assetRegistryLookupAddr);

            assetRegistryContract = new AssetContractLookup((web3 as any), assetRegistryLookupAddr);
            originRegistryContract = new OriginContractLookup((web3 as any));
            certificateLogic = new CertificateLogic((web3 as any));
            certificateDB = new CertificateDB((web3 as any));
            assetRegistry = new AssetProducingRegistryLogic((web3 as any), assetProducingAddr);

            Object.keys(originContracts).forEach(async (key) => {

                const deployedBytecode = await web3.eth.getCode(originContracts[key]);
                assert.isTrue(deployedBytecode.length > 0);

                const contractInfo = JSON.parse(fs.readFileSync(key, 'utf8'));

                const tempBytecode = '0x' + contractInfo.deployedBytecode;
                assert.equal(deployedBytecode, tempBytecode);

            });
        });

        it('should deploy a testreceiver-contract', async () => {
            const sloffle = new Sloffle(web3);

            const addressTest = await sloffle.deploy(process.cwd() + '/dist/contracts/TestReceiver.json', [certificateLogic.web3Contract._address], {
                privateKey: privateKeyDeployment,
            });

            testreceiver = new TestReceiver(web3, addressTest[0]);

        });

        it('should have the right owner', async () => {

            assert.equal(await certificateLogic.owner(), originRegistryContract.web3Contract._address);

        });

        it('should have the lookup-contracts', async () => {

            assert.equal(await certificateLogic.assetContractLookup(), assetRegistryContract.web3Contract._address);
            assert.equal(await certificateLogic.userContractLookup(), userRegistryContract.web3Contract._address);
        });

        it('should the correct DB', async () => {

            assert.equal(await certificateLogic.db(), certificateDB.web3Contract._address);
        });

        it('should have balances of 0', async () => {

            assert.equal(await certificateLogic.balanceOf(accountDeployment), 0);
            assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 0);
            assert.equal(await certificateLogic.balanceOf(accountTrader), 0);

        });

        it('should throw for balance of address 0x0', async () => {

            let failed = false;
            try {
                await certificateLogic.balanceOf('0x0000000000000000000000000000000000000000');
            } catch (ex) {
                failed = true;
            }

            assert.isTrue(failed);
        });

        it('should throw when trying to access a non existing certificate', async () => {
            let failed = false;
            try {
                await certificateLogic.ownerOf(0);
            } catch (ex) {
                failed = true;
            }

            assert.isTrue(failed);
        });

        it('should throw when trying to call safeTransferFrom a non existing certificate', async () => {
            let failed = false;
            try {
                await certificateLogic.safeTransferFrom(accountDeployment, accountTrader, 0, '0x00', { privateKey: privateKeyDeployment });
            } catch (ex) {
                failed = true;
            }

            assert.isTrue(failed);
        });

        it('should throw when trying to call safeTransferFrom a non existing certificate', async () => {
            let failed = false;
            try {
                await certificateLogic.safeTransferFrom(accountDeployment, accountTrader, 0, { privateKey: privateKeyDeployment });
            } catch (ex) {
                failed = true;
            }

            assert.isTrue(failed);
        });

        it('should throw when trying to call transferFrom a non existing certificate', async () => {
            let failed = false;
            try {
                await certificateLogic.transferFrom(accountDeployment, accountTrader, 0, { privateKey: privateKeyDeployment });
            } catch (ex) {
                failed = true;
            }

            assert.isTrue(failed);
        });

        it('should throw when trying to call approve a non existing certificate', async () => {
            let failed = false;
            try {
                await certificateLogic.approve(accountTrader, 0, { privateKey: privateKeyDeployment });
            } catch (ex) {
                failed = true;
            }

            assert.isTrue(failed);
        });

        it('should set right roles to users', async () => {
            await userLogic.setUser(accountTrader, 'trader', { privateKey: privateKeyDeployment });
            await userLogic.setUser(accountAssetOwner, 'assetOwner', { privateKey: privateKeyDeployment });
            await userLogic.setUser(testreceiver.web3Contract._address, 'testreceiver', { privateKey: privateKeyDeployment });

            await userLogic.setRoles(testreceiver.web3Contract._address, 16, { privateKey: privateKeyDeployment });
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

            assert.isTrue(await certificateLogic.supportsInterface('0x80ac58cd'));
            assert.isFalse(await certificateLogic.supportsInterface('0x80ac58c1'));

        });

        describe('transferFrom', () => {

            it('should have 0 certificates', async () => {
                assert.equal(await certificateLogic.getCertificateListLength(), 0);
            });

            it('should log energy', async () => {

                const tx = await assetRegistry.saveSmartMeterRead(
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
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

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
                assert.equal(await certificateLogic.getCertificateListLength(), 1);
            });

            it('should return the certificate', async () => {
                const cert = await certificateLogic.getCertificate(0);

                //  const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');

                //  const contract = new ethers.Contract(certificateLogic.web3Contract._address, certificateLogic.web3Contract.options.jsonInterface, provider);

                //   console.log('ethers:');
                //   console.log(await contract.getCertificate(0));

                const certificateSpecific = cert.certificateSpecific;

                assert.isFalse(certificateSpecific.retired);
                assert.equal(certificateSpecific.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(certificateSpecific.coSaved, 100);
                assert.equal(certificateSpecific.parentId, 0);
                assert.equal(certificateSpecific.children.length, 0);
                assert.equal(certificateSpecific.maxOwnerChanges, 2);
                assert.equal(certificateSpecific.ownerChangeCounter, 0);

                const tradableEntity = cert.tradableEntity;

                assert.equal(tradableEntity.assetId, 0);
                assert.equal(tradableEntity.owner, accountAssetOwner);
                assert.equal(tradableEntity.powerInW, 100);
                assert.equal(tradableEntity.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntity.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntity.escrow, ['0x1000000000000000000000000000000000000005']);
                assert.equal(tradableEntity.approvedAddress, '0x0000000000000000000000000000000000000000');

            });

            it('should hava balance of 1 for assetOwner address', async () => {

                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 1);

            });

            it('should return the correct owner', async () => {

                assert.equal(await certificateLogic.ownerOf(0), accountAssetOwner);

            });

            it('should return correct approvedFor', async () => {

                assert.equal(await certificateLogic.getApproved(0), '0x0000000000000000000000000000000000000000');

            });

            it('should return correct isApprovedForAll', async () => {

                assert.isFalse(await certificateLogic.isApprovedForAll(accountAssetOwner, accountDeployment));
                assert.isFalse(await certificateLogic.isApprovedForAll(accountAssetOwner, accountTrader));

            });

            it('should split the certificate', async () => {

                const tx = await certificateLogic.splitCertificate(0, 40, { privateKey: assetOwnerPK });

                assert.equal(await certificateLogic.getCertificateListLength(), 3);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 3);

                // Parent
                const certParent = await certificateLogic.getCertificate(0);
                const certificateSpecificParent = certParent.certificateSpecific;

                assert.isFalse(certificateSpecificParent.retired);
                assert.equal(certificateSpecificParent.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(certificateSpecificParent.coSaved, 100);
                assert.equal(certificateSpecificParent.parentId, 0);
                // TODO: why is: AssertionError: expected [ '1', '2' ] to equal [ '1', '2' ]
                assert.equal(certificateSpecificParent.children.length, 2);
                assert.equal(certificateSpecificParent.maxOwnerChanges, 2);
                assert.equal(certificateSpecificParent.ownerChangeCounter, 0);

                const tradableEntityParent = certParent.tradableEntity;
                assert.equal(tradableEntityParent.assetId, 0);
                assert.equal(tradableEntityParent.owner, accountAssetOwner);
                assert.equal(tradableEntityParent.powerInW, 100);
                assert.equal(tradableEntityParent.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntityParent.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntityParent.escrow, ['0x1000000000000000000000000000000000000005']);
                assert.equal(tradableEntityParent.approvedAddress, '0x0000000000000000000000000000000000000000');

                // child 1
                const certChildOne = await certificateLogic.getCertificate(1);
                const certificateSpecificChildOne = certChildOne.certificateSpecific;
                assert.isFalse(certificateSpecificChildOne.retired);
                assert.equal(certificateSpecificChildOne.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(certificateSpecificChildOne.coSaved, 40);
                assert.equal(certificateSpecificChildOne.parentId, 0);
                // TODO: why is: AssertionError: expected [ '1', '2' ] to equal [ '1', '2' ]
                assert.equal(certificateSpecificChildOne.children.length, 0);
                assert.equal(certificateSpecificChildOne.maxOwnerChanges, 2);
                assert.equal(certificateSpecificChildOne.ownerChangeCounter, 0);

                const tradableEntityChildOne = certChildOne.tradableEntity;
                assert.equal(tradableEntityChildOne.assetId, 0);
                assert.equal(tradableEntityChildOne.owner, accountAssetOwner);
                assert.equal(tradableEntityChildOne.powerInW, 40);
                assert.equal(tradableEntityChildOne.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntityChildOne.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntityChildOne.escrow, ['0x1000000000000000000000000000000000000005']);
                assert.equal(tradableEntityChildOne.approvedAddress, '0x0000000000000000000000000000000000000000');

                // child 2
                const certChildTwo = await certificateLogic.getCertificate(2);
                const certificateSpecificChildTwo = certChildTwo.certificateSpecific;
                assert.isFalse(certificateSpecificChildTwo.retired);
                assert.equal(certificateSpecificChildTwo.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(certificateSpecificChildTwo.coSaved, 60);
                assert.equal(certificateSpecificChildTwo.parentId, 0);
                // TODO: why is: AssertionError: expected [ '1', '2' ] to equal [ '1', '2' ]
                assert.equal(certificateSpecificChildTwo.children.length, 0);
                assert.equal(certificateSpecificChildTwo.maxOwnerChanges, 2);
                assert.equal(certificateSpecificChildTwo.ownerChangeCounter, 0);

                const tradableEntityChildTwo = certChildTwo.tradableEntity;
                assert.equal(tradableEntityChildTwo.assetId, 0);
                assert.equal(tradableEntityChildTwo.owner, accountAssetOwner);
                assert.equal(tradableEntityChildTwo.powerInW, 60);
                assert.equal(tradableEntityChildTwo.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntityChildTwo.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntityChildTwo.escrow, ['0x1000000000000000000000000000000000000005']);
                assert.equal(tradableEntityChildTwo.approvedAddress, '0x0000000000000000000000000000000000000000');

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 2);

                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '1',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '1',
                    });

                    assert.equal(allTransferEvents[1].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[1].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '2',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '2',
                    });

                    const certSplittedEvent = await certificateLogic.getAllLogCertificateSplitEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });
                    assert.equal(certSplittedEvent.length, 1);

                    assert.equal(certSplittedEvent[0].event, 'LogCertificateSplit');
                    assert.deepEqual(certSplittedEvent[0].returnValues, {
                        0: '0',
                        1: '1',
                        2: '2',
                        _certificateId: '0',
                        _childOne: '1',
                        _childTwo: '2',
                    });
                }
            });

            it('should throw when trying to call transferFrom as an admin that does not own that', async () => {
                let failed = false;
                try {
                    await certificateLogic.transferFrom(accountAssetOwner, accountTrader, 1, { privateKey: privateKeyDeployment });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call transferFrom as an trader that does not own that', async () => {
                let failed = false;
                try {
                    await certificateLogic.transferFrom(accountAssetOwner, accountTrader, 1, { privateKey: traderPK });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call transferFrom using wrong _from', async () => {
                let failed = false;
                try {
                    await certificateLogic.transferFrom(accountDeployment, accountTrader, 1, { privateKey: assetOwnerPK });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call transferFrom as an admin on a split certificate', async () => {
                let failed = false;
                try {
                    await certificateLogic.transferFrom(accountAssetOwner, accountTrader, 0, { privateKey: privateKeyDeployment });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call transferFrom as an trader on a split certificate', async () => {
                let failed = false;
                try {
                    await certificateLogic.transferFrom(accountAssetOwner, accountTrader, 0, { privateKey: traderPK });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call transferFrom on a split certificate', async () => {
                let failed = false;
                try {
                    await certificateLogic.transferFrom(accountAssetOwner, accountTrader, 0, { privateKey: assetOwnerPK });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should be able to do transferFrom', async () => {

                //       await certificateLogic.approve(accountAssetOwner, 1, { privateKey: assetOwnerPK });

                const tx = await certificateLogic.transferFrom(accountAssetOwner, accountTrader, 1, { privateKey: assetOwnerPK });

                assert.equal(await certificateLogic.getCertificateListLength(), 3);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 1);

                if (isGanache) {
                    const allEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allEvents.length, 1);
                    assert.equal(allEvents[0].event, 'Transfer');
                    assert.deepEqual(allEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: accountTrader,
                        2: '1',
                        _from: accountAssetOwner,
                        _to: accountTrader,
                        _tokenId: '1',
                    });
                }
            });

            it('should return the certificate', async () => {
                const cert = await certificateLogic.getCertificate(1);

                const certificateSpecific = cert.certificateSpecific;

                assert.isFalse(certificateSpecific.retired);
                assert.equal(certificateSpecific.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(certificateSpecific.coSaved, 40);
                assert.equal(certificateSpecific.parentId, 0);
                assert.equal(certificateSpecific.children.length, 0);
                assert.equal(certificateSpecific.maxOwnerChanges, 2);
                assert.equal(certificateSpecific.ownerChangeCounter, 1);

                const tradableEntity = cert.tradableEntity;

                assert.equal(tradableEntity.assetId, 0);
                assert.equal(tradableEntity.owner, accountTrader);
                assert.equal(tradableEntity.powerInW, 40);
                assert.equal(tradableEntity.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntity.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntity.escrow, []);
                assert.equal(tradableEntity.approvedAddress, '0x0000000000000000000000000000000000000000');

            });

            it('should be able to transfer the certiificate a 2nd time ', async () => {

                //       await certificateLogic.approve(accountAssetOwner, 1, { privateKey: assetOwnerPK });

                const tx = await certificateLogic.transferFrom(accountTrader, accountTrader, 1, { privateKey: traderPK });

                assert.equal(await certificateLogic.getCertificateListLength(), 3);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 1);

                if (isGanache) {
                    const allEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allEvents.length, 1);
                    assert.equal(allEvents[0].event, 'Transfer');
                    assert.deepEqual(allEvents[0].returnValues, {
                        0: accountTrader,
                        1: accountTrader,
                        2: '1',
                        _from: accountTrader,
                        _to: accountTrader,
                        _tokenId: '1',
                    });
                }
                const retireEvent = await certificateLogic.getAllLogCertificateRetiredEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                assert.equal(retireEvent.length, 1);
                assert.equal(retireEvent[0].event, 'LogCertificateRetired');
                assert.deepEqual(retireEvent[0].returnValues, {
                    0: '1', 1: true, _certificateId: '1', _retire: true,
                });
            });

            it('should return the certificate (should have retired it)', async () => {
                const cert = await certificateLogic.getCertificate(1);

                const certificateSpecific = cert.certificateSpecific;

                assert.isTrue(certificateSpecific.retired);
                assert.equal(certificateSpecific.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(certificateSpecific.coSaved, 40);
                assert.equal(certificateSpecific.parentId, 0);
                assert.equal(certificateSpecific.children.length, 0);
                assert.equal(certificateSpecific.maxOwnerChanges, 2);
                assert.equal(certificateSpecific.ownerChangeCounter, 2);

                const tradableEntity = cert.tradableEntity;

                assert.equal(tradableEntity.assetId, 0);
                assert.equal(tradableEntity.owner, accountTrader);
                assert.equal(tradableEntity.powerInW, 40);
                assert.equal(tradableEntity.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntity.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntity.escrow, []);
                assert.equal(tradableEntity.approvedAddress, '0x0000000000000000000000000000000000000000');

            });

            it('should throw when trying to call transferFrom on a retired certificate', async () => {
                let failed = false;
                try {
                    await certificateLogic.transferFrom(accountTrader, accountTrader, 1, { privateKey: traderPK });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call split on a retired certificate', async () => {
                let failed = false;
                try {
                    await certificateLogic.splitCertificate(1, 20, { privateKey: traderPK });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call transferFrom on a splitted certificate', async () => {
                let failed = false;
                try {
                    await certificateLogic.transferFrom(accountTrader, accountTrader, 0, { privateKey: assetOwnerPK });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call split on a splitted certificate', async () => {
                let failed = false;
                try {
                    await certificateLogic.splitCertificate(0, 20, { privateKey: assetOwnerPK });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

        });

        describe('saveTransferFrom without data', () => {
            it('should log energy again (certificate #3)', async () => {

                const tx = await assetRegistry.saveSmartMeterRead(
                    0,
                    200,
                    false,
                    'lastSmartMeterReadFileHash',
                    200,
                    false,
                    { privateKey: assetSmartmeterPK });

                const event = (await assetRegistry.getAllLogNewMeterReadEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber }))[0];

                assert.equal(event.event, 'LogNewMeterRead');
                assert.deepEqual(event.returnValues, {
                    0: '0',
                    1: '100',
                    2: '200',
                    3: false,
                    4: '100',
                    5: '100',
                    6: '200',
                    7: false,
                    _assetId: '0',
                    _oldMeterRead: '100',
                    _newMeterRead: '200',
                    _smartMeterDown: false,
                    _certificatesCreatedForWh: '100',
                    _oldCO2OffsetReading: '100',
                    _newCO2OffsetReading: '200',
                    _serviceDown: false,
                });

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '3',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '3',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 4);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 3);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 1);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 0);

            });

            it('should return the certificate #3', async () => {
                const cert = await certificateLogic.getCertificate(3);

                const certificateSpecific = cert.certificateSpecific;

                assert.isFalse(certificateSpecific.retired);
                assert.equal(certificateSpecific.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(certificateSpecific.coSaved, 100);
                assert.equal(certificateSpecific.parentId, 3);
                assert.equal(certificateSpecific.children.length, 0);
                assert.equal(certificateSpecific.maxOwnerChanges, 2);
                assert.equal(certificateSpecific.ownerChangeCounter, 0);

                const tradableEntity = cert.tradableEntity;

                assert.equal(tradableEntity.assetId, 0);
                assert.equal(tradableEntity.owner, accountAssetOwner);
                assert.equal(tradableEntity.powerInW, 100);
                assert.equal(tradableEntity.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntity.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntity.escrow, ['0x1000000000000000000000000000000000000005']);
                assert.equal(tradableEntity.approvedAddress, '0x0000000000000000000000000000000000000000');

            });

            it('should throw when trying to call safetransferFrom as non owner(admin) and wrong receiver', async () => {
                let failed = false;
                try {

                    await certificateLogic.safeTransferFrom(accountAssetOwner, accountTrader, 3, '', { privateKey: privateKeyDeployment });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call safetransferFrom as non owner (trader) and wrong receiver', async () => {
                let failed = false;
                try {

                    await certificateLogic.safeTransferFrom(accountAssetOwner, accountTrader, 3, '', { privateKey: traderPK });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call safetransferFrom as assetManager and wrong receiver ', async () => {
                let failed = false;
                try {

                    await certificateLogic.safeTransferFrom(accountAssetOwner, accountTrader, 3, '', { privateKey: privateKeyDeployment });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call safetransferFrom as non owner(admin) and correct receiver', async () => {
                let failed = false;
                try {

                    await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 3, '', { privateKey: privateKeyDeployment });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call safetransferFrom as non owner (trader) and correct receiver', async () => {
                let failed = false;
                try {

                    await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 3, '', { privateKey: traderPK });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should call safetransferFrom as assetManager and correct receiver ', async () => {

                const tx = await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 3, '', { privateKey: assetOwnerPK });

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: testreceiver.web3Contract._address,
                        2: '3',
                        _from: accountAssetOwner,
                        _to: testreceiver.web3Contract._address,
                        _tokenId: '3',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 4);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 1);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 1);
            });

            it('should return the certificate #3 again', async () => {
                const cert = await certificateLogic.getCertificate(3);

                const certificateSpecific = cert.certificateSpecific;

                assert.isFalse(certificateSpecific.retired);
                assert.equal(certificateSpecific.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(certificateSpecific.coSaved, 100);
                assert.equal(certificateSpecific.parentId, 3);
                assert.equal(certificateSpecific.children.length, 0);
                assert.equal(certificateSpecific.maxOwnerChanges, 2);
                assert.equal(certificateSpecific.ownerChangeCounter, 1);

                const tradableEntity = cert.tradableEntity;

                assert.equal(tradableEntity.assetId, 0);
                assert.equal(tradableEntity.owner, testreceiver.web3Contract._address);
                assert.equal(tradableEntity.powerInW, 100);
                assert.equal(tradableEntity.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntity.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntity.escrow, []);
                assert.equal(tradableEntity.approvedAddress, '0x0000000000000000000000000000000000000000');

            });

            it('should be able to transfer token again', async () => {
                const tx = await testreceiver.safeTransferFrom(testreceiver.web3Contract._address,
                                                               testreceiver.web3Contract._address,
                                                               3, '', {
                        privateKey: traderPK,
                    });

                const cert = await certificateLogic.getCertificate(3);

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: testreceiver.web3Contract._address,
                        1: testreceiver.web3Contract._address,
                        2: '3',
                        _from: testreceiver.web3Contract._address,
                        _to: testreceiver.web3Contract._address,
                        _tokenId: '3',
                    });
                }
                const retireEvent = await certificateLogic.getAllLogCertificateRetiredEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                assert.equal(retireEvent.length, 1);
                assert.equal(retireEvent[0].event, 'LogCertificateRetired');
                assert.deepEqual(retireEvent[0].returnValues, {
                    0: '3', 1: true, _certificateId: '3', _retire: true,
                });

                assert.equal(await certificateLogic.getCertificateListLength(), 4);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 1);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 1);

            });

            it('should return the certificate #3 again', async () => {
                const cert = await certificateLogic.getCertificate(3);

                const certificateSpecific = cert.certificateSpecific;

                assert.isTrue(certificateSpecific.retired);
                assert.equal(certificateSpecific.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(certificateSpecific.coSaved, 100);
                assert.equal(certificateSpecific.parentId, 3);
                assert.equal(certificateSpecific.children.length, 0);
                assert.equal(certificateSpecific.maxOwnerChanges, 2);
                assert.equal(certificateSpecific.ownerChangeCounter, 2);

                const tradableEntity = cert.tradableEntity;

                assert.equal(tradableEntity.assetId, 0);
                assert.equal(tradableEntity.owner, testreceiver.web3Contract._address);
                assert.equal(tradableEntity.powerInW, 100);
                assert.equal(tradableEntity.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntity.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntity.escrow, []);
                assert.equal(tradableEntity.approvedAddress, '0x0000000000000000000000000000000000000000');

            });

        });

        describe('saveTransferFrom with data', () => {
            it('should log energy again (certificate #4)', async () => {

                const tx = await assetRegistry.saveSmartMeterRead(
                    0,
                    300,
                    false,
                    'lastSmartMeterReadFileHash',
                    300,
                    false,
                    { privateKey: assetSmartmeterPK });

                const event = (await assetRegistry.getAllLogNewMeterReadEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber }))[0];

                assert.equal(event.event, 'LogNewMeterRead');
                assert.deepEqual(event.returnValues, {
                    0: '0',
                    1: '200',
                    2: '300',
                    3: false,
                    4: '100',
                    5: '200',
                    6: '300',
                    7: false,
                    _assetId: '0',
                    _oldMeterRead: '200',
                    _newMeterRead: '300',
                    _smartMeterDown: false,
                    _certificatesCreatedForWh: '100',
                    _oldCO2OffsetReading: '200',
                    _newCO2OffsetReading: '300',
                    _serviceDown: false,
                });

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '4',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '4',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 5);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 3);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 1);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 1);

            });

            it('should return the certificate #4', async () => {
                const cert = await certificateLogic.getCertificate(4);

                const certificateSpecific = cert.certificateSpecific;

                assert.isFalse(certificateSpecific.retired);
                assert.equal(certificateSpecific.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(certificateSpecific.coSaved, 100);
                assert.equal(certificateSpecific.parentId, 4);
                assert.equal(certificateSpecific.children.length, 0);
                assert.equal(certificateSpecific.maxOwnerChanges, 2);
                assert.equal(certificateSpecific.ownerChangeCounter, 0);

                const tradableEntity = cert.tradableEntity;

                assert.equal(tradableEntity.assetId, 0);
                assert.equal(tradableEntity.owner, accountAssetOwner);
                assert.equal(tradableEntity.powerInW, 100);
                assert.equal(tradableEntity.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntity.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntity.escrow, ['0x1000000000000000000000000000000000000005']);
                assert.equal(tradableEntity.approvedAddress, '0x0000000000000000000000000000000000000000');

            });

            it('should throw when trying to call safetransferFrom as non owner(admin) and wrong receiver', async () => {
                let failed = false;
                try {

                    await certificateLogic.safeTransferFrom(accountAssetOwner, accountTrader, 4, '0x01', { privateKey: privateKeyDeployment });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call safetransferFrom as non owner (trader) and wrong receiver', async () => {
                let failed = false;
                try {

                    await certificateLogic.safeTransferFrom(accountAssetOwner, accountTrader, 4, '0x01', { privateKey: traderPK });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call safetransferFrom as assetManager and wrong receiver ', async () => {
                let failed = false;
                try {

                    await certificateLogic.safeTransferFrom(accountAssetOwner, accountTrader, 4, '0x01', { privateKey: privateKeyDeployment });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call safetransferFrom as non owner(admin) and correct receiver', async () => {
                let failed = false;
                try {

                    await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 4, '0x01', { privateKey: privateKeyDeployment });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should throw when trying to call safetransferFrom as non owner (trader) and correct receiver', async () => {
                let failed = false;
                try {

                    await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 4, '0x01', { privateKey: traderPK });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should call safetransferFrom as assetManager and correct receiver ', async () => {

                const tx = await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 4, '0x01', { privateKey: assetOwnerPK });

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: testreceiver.web3Contract._address,
                        2: '4',
                        _from: accountAssetOwner,
                        _to: testreceiver.web3Contract._address,
                        _tokenId: '4',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 5);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 1);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 2);
            });

            it('should return the certificate #4 again', async () => {
                const cert = await certificateLogic.getCertificate(4);

                const certificateSpecific = cert.certificateSpecific;

                assert.isFalse(certificateSpecific.retired);
                assert.equal(certificateSpecific.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(certificateSpecific.coSaved, 100);
                assert.equal(certificateSpecific.parentId, 4);
                assert.equal(certificateSpecific.children.length, 0);
                assert.equal(certificateSpecific.maxOwnerChanges, 2);
                assert.equal(certificateSpecific.ownerChangeCounter, 1);

                const tradableEntity = cert.tradableEntity;

                assert.equal(tradableEntity.assetId, 0);
                assert.equal(tradableEntity.owner, testreceiver.web3Contract._address);
                assert.equal(tradableEntity.powerInW, 100);
                assert.equal(tradableEntity.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntity.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntity.escrow, []);
                assert.equal(tradableEntity.approvedAddress, '0x0000000000000000000000000000000000000000');

            });

            it('should be able to transfer token again', async () => {
                const tx = await testreceiver.safeTransferFrom(testreceiver.web3Contract._address,
                                                               testreceiver.web3Contract._address,
                                                               4, '0x01', {
                        privateKey: traderPK,
                    });

                const cert = await certificateLogic.getCertificate(4);
                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: testreceiver.web3Contract._address,
                        1: testreceiver.web3Contract._address,
                        2: '4',
                        _from: testreceiver.web3Contract._address,
                        _to: testreceiver.web3Contract._address,
                        _tokenId: '4',
                    });
                }
                const retireEvent = await certificateLogic.getAllLogCertificateRetiredEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                assert.equal(retireEvent.length, 1);
                assert.equal(retireEvent[0].event, 'LogCertificateRetired');
                assert.deepEqual(retireEvent[0].returnValues, {
                    0: '4', 1: true, _certificateId: '4', _retire: true,
                });

                assert.equal(await certificateLogic.getCertificateListLength(), 5);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 1);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 2);

            });

            it('should return the certificate #4 again', async () => {
                const cert = await certificateLogic.getCertificate(4);

                const certificateSpecific = cert.certificateSpecific;

                assert.isTrue(certificateSpecific.retired);
                assert.equal(certificateSpecific.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(certificateSpecific.coSaved, 100);
                assert.equal(certificateSpecific.parentId, 4);
                assert.equal(certificateSpecific.children.length, 0);
                assert.equal(certificateSpecific.maxOwnerChanges, 2);
                assert.equal(certificateSpecific.ownerChangeCounter, 2);

                const tradableEntity = cert.tradableEntity;

                assert.equal(tradableEntity.assetId, 0);
                assert.equal(tradableEntity.owner, testreceiver.web3Contract._address);
                assert.equal(tradableEntity.powerInW, 100);
                assert.equal(tradableEntity.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntity.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntity.escrow, []);
                assert.equal(tradableEntity.approvedAddress, '0x0000000000000000000000000000000000000000');

            });

        });
        describe('escrow and approval', () => {
            it('should set an escrow to the asset', async () => {
                await assetRegistry.addMatcher(0, matcherAccount, { privateKey: assetOwnerPK });
                assert.deepEqual(await assetRegistry.getMatcher(0),
                                 ['0x1000000000000000000000000000000000000005', matcherAccount]);
            });

            it('should return correct approval', async () => {
                assert.isFalse(await certificateLogic.isApprovedForAll(accountAssetOwner, approvedAccount));
                assert.isFalse(await certificateLogic.isApprovedForAll(accountTrader, approvedAccount));

                const tx = await certificateLogic.setApprovalForAll(approvedAccount, true, { privateKey: assetOwnerPK });
                assert.isTrue(await certificateLogic.isApprovedForAll(accountAssetOwner, approvedAccount));
                assert.isFalse(await certificateLogic.isApprovedForAll(accountTrader, approvedAccount));

                const allApprovalEvents = await certificateLogic.getAllApprovalForAllEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                assert.equal(allApprovalEvents.length, 1);
                assert.equal(allApprovalEvents[0].event, 'ApprovalForAll');
                assert.deepEqual(allApprovalEvents[0].returnValues, {
                    0: accountAssetOwner,
                    1: approvedAccount,
                    2: true,
                    _owner: accountAssetOwner,
                    _operator: approvedAccount,
                    _approved: true,
                });
            });

            it('should add 2nd approval', async () => {
                const tx = await certificateLogic.setApprovalForAll('0x1000000000000000000000000000000000000005', true, { privateKey: assetOwnerPK });
                const allApprovalEvents = await certificateLogic.getAllApprovalForAllEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                assert.equal(allApprovalEvents.length, 1);
                assert.equal(allApprovalEvents[0].event, 'ApprovalForAll');
                assert.deepEqual(allApprovalEvents[0].returnValues, {
                    0: accountAssetOwner,
                    1: '0x1000000000000000000000000000000000000005',
                    2: true,
                    _owner: accountAssetOwner,
                    _operator: '0x1000000000000000000000000000000000000005',
                    _approved: true,
                });

                assert.isTrue(await certificateLogic.isApprovedForAll(accountAssetOwner, approvedAccount));
                assert.isTrue(await certificateLogic.isApprovedForAll(accountAssetOwner, '0x1000000000000000000000000000000000000005'));

            });

            it('should remove approval', async () => {
                const tx = await certificateLogic.setApprovalForAll('0x1000000000000000000000000000000000000005', false, { privateKey: assetOwnerPK });
                const allApprovalEvents = await certificateLogic.getAllApprovalForAllEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                assert.equal(allApprovalEvents.length, 1);
                assert.equal(allApprovalEvents[0].event, 'ApprovalForAll');
                assert.deepEqual(allApprovalEvents[0].returnValues, {
                    0: accountAssetOwner,
                    1: '0x1000000000000000000000000000000000000005',
                    2: false,
                    _owner: accountAssetOwner,
                    _operator: '0x1000000000000000000000000000000000000005',
                    _approved: false,
                });

                assert.isTrue(await certificateLogic.isApprovedForAll(accountAssetOwner, approvedAccount));
                assert.isFalse(await certificateLogic.isApprovedForAll(accountAssetOwner, '0x1000000000000000000000000000000000000005'));

            });

            it('should return correct getApproved', async () => {

                assert.equal(await certificateLogic.getApproved(0), '0x0000000000000000000000000000000000000000');
                assert.equal(await certificateLogic.getApproved(1), '0x0000000000000000000000000000000000000000');
                assert.equal(await certificateLogic.getApproved(2), '0x0000000000000000000000000000000000000000');
                assert.equal(await certificateLogic.getApproved(3), '0x0000000000000000000000000000000000000000');
                assert.equal(await certificateLogic.getApproved(4), '0x0000000000000000000000000000000000000000');

                await certificateLogic.approve('0x1000000000000000000000000000000000000005', 2, { privateKey: assetOwnerPK });

                assert.equal(await certificateLogic.getApproved(0), '0x0000000000000000000000000000000000000000');
                assert.equal(await certificateLogic.getApproved(1), '0x0000000000000000000000000000000000000000');
                assert.equal(await certificateLogic.getApproved(2), '0x1000000000000000000000000000000000000005');
                assert.equal(await certificateLogic.getApproved(3), '0x0000000000000000000000000000000000000000');
                assert.equal(await certificateLogic.getApproved(4), '0x0000000000000000000000000000000000000000');

            });

            it('should throw when calling getApproved for a non valid token', async () => {

                let failed = false;
                try {
                    await certificateLogic.getApproved(5);
                } catch (ex) {
                    failed = true;
                }
                assert.isTrue(failed);
            });

            it('should throw trying to transfer old certificate with new matcher', async () => {

                let failed = false;
                try {
                    await certificateLogic.transferFrom(accountAssetOwner, accountTrader, 2, { privateKey: matcherPK });

                } catch (ex) {
                    failed = true;
                    if (isGanache) {
                        assert.include(ex.message, 'revert user does not have the required role');
                    }
                }
                assert.isTrue(failed);
            });

            it('should log energy again (certificate #5)', async () => {

                const tx = await assetRegistry.saveSmartMeterRead(
                    0,
                    400,
                    false,
                    'lastSmartMeterReadFileHash',
                    400,
                    false,
                    { privateKey: assetSmartmeterPK });

                const event = (await assetRegistry.getAllLogNewMeterReadEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber }))[0];

                assert.equal(event.event, 'LogNewMeterRead');
                assert.deepEqual(event.returnValues, {
                    0: '0',
                    1: '300',
                    2: '400',
                    3: false,
                    4: '100',
                    5: '300',
                    6: '400',
                    7: false,
                    _assetId: '0',
                    _oldMeterRead: '300',
                    _newMeterRead: '400',
                    _smartMeterDown: false,
                    _certificatesCreatedForWh: '100',
                    _oldCO2OffsetReading: '300',
                    _newCO2OffsetReading: '400',
                    _serviceDown: false,
                });

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '5',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '5',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 6);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 3);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 1);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 2);
            });

            it('should return the certificate #5 again', async () => {
                const cert = await certificateLogic.getCertificate(5);

                const certificateSpecific = cert.certificateSpecific;

                assert.isFalse(certificateSpecific.retired);
                assert.equal(certificateSpecific.dataLog, 'lastSmartMeterReadFileHash');
                assert.equal(certificateSpecific.coSaved, 100);
                assert.equal(certificateSpecific.parentId, 5);
                assert.equal(certificateSpecific.children.length, 0);
                assert.equal(certificateSpecific.maxOwnerChanges, 2);
                assert.equal(certificateSpecific.ownerChangeCounter, 0);

                const tradableEntity = cert.tradableEntity;

                assert.equal(tradableEntity.assetId, 0);
                assert.equal(tradableEntity.owner, accountAssetOwner);
                assert.equal(tradableEntity.powerInW, 100);
                assert.equal(tradableEntity.acceptedToken, '0x0000000000000000000000000000000000000000');
                assert.equal(tradableEntity.onChainDirectPurchasePrice, 0);
                assert.deepEqual(tradableEntity.escrow, ['0x1000000000000000000000000000000000000005', matcherAccount]);
                assert.equal(tradableEntity.approvedAddress, '0x0000000000000000000000000000000000000000');

            });

            it('should throw trying to transfer old certificate with new matcher but missing role', async () => {

                let failed = false;
                try {
                    await certificateLogic.transferFrom(accountAssetOwner, accountTrader, 5, { privateKey: matcherPK });

                } catch (ex) {
                    failed = true;
                    if (isGanache) {
                        assert.include(ex.message, 'revert user does not have the required role');
                    }
                }
                assert.isTrue(failed);
            });

            it('should throw trying to safeTransferFrom without data old certificate with new matcher but missing role', async () => {

                let failed = false;
                try {
                    const tx = await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 5, null, { privateKey: matcherPK });

                } catch (ex) {
                    failed = true;
                    if (isGanache) {
                        assert.include(ex.message, 'revert user does not have the required role');
                    }
                }
                assert.isTrue(failed);
            });

            it('should throw trying to safeTransferFrom with data old certificate with new matcher but missing role', async () => {

                let failed = false;
                try {
                    const tx = await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 5, '0x01', { privateKey: matcherPK });

                } catch (ex) {
                    failed = true;
                    if (isGanache) {
                        assert.include(ex.message, 'revert user does not have the required role');
                    }
                }
                assert.isTrue(failed);
            });

            it('should set matcherAccount roles', async () => {
                await userLogic.setUser(matcherAccount, 'matcherAccount', { privateKey: privateKeyDeployment });
                await userLogic.setRoles(matcherAccount, 16, { privateKey: privateKeyDeployment });
            });

            it('should transfer certificate #5 as matcher', async () => {

                // console.log(await certificateLogic.checkMatcher((await assetRegistry.getMatcher(5) as any)));
                assert.equal(await certificateLogic.getApproved(5), '0x0000000000000000000000000000000000000000');

                const tx = await certificateLogic.transferFrom(
                    accountAssetOwner,
                    accountTrader,
                    5,
                    { privateKey: matcherPK });
                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: accountTrader,
                        2: '5',
                        _from: accountAssetOwner,
                        _to: accountTrader,
                        _tokenId: '5',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 6);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 2);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 2);
                assert.equal(await certificateLogic.getApproved(5), '0x0000000000000000000000000000000000000000');

            });

            it('should throw trying to call transer certificate #5 with matcher after it has been transfered', async () => {

                let failed = false;
                try {
                    await certificateLogic.transferFrom(accountTrader, accountTrader, 5, { privateKey: matcherPK });

                } catch (ex) {
                    failed = true;
                }
                assert.isTrue(failed);
            });

            it('should log energy again (certificate #6)', async () => {

                const tx = await assetRegistry.saveSmartMeterRead(
                    0,
                    500,
                    false,
                    'lastSmartMeterReadFileHash',
                    500,
                    false,
                    { privateKey: assetSmartmeterPK });

                const event = (await assetRegistry.getAllLogNewMeterReadEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber }))[0];

                assert.equal(event.event, 'LogNewMeterRead');
                assert.deepEqual(event.returnValues, {
                    0: '0',
                    1: '400',
                    2: '500',
                    3: false,
                    4: '100',
                    5: '400',
                    6: '500',
                    7: false,
                    _assetId: '0',
                    _oldMeterRead: '400',
                    _newMeterRead: '500',
                    _smartMeterDown: false,
                    _certificatesCreatedForWh: '100',
                    _oldCO2OffsetReading: '400',
                    _newCO2OffsetReading: '500',
                    _serviceDown: false,
                });

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '6',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '6',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 7);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 3);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 2);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 2);
            });

            it('should transferFrom without data certificate #6 as matcher', async () => {

                assert.equal(await certificateLogic.getApproved(6), '0x0000000000000000000000000000000000000000');

                const tx = await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 6, null, { privateKey: matcherPK });
                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: testreceiver.web3Contract._address,
                        2: '6',
                        _from: accountAssetOwner,
                        _to: testreceiver.web3Contract._address,
                        _tokenId: '6',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 7);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 2);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 3);
                assert.equal(await certificateLogic.getApproved(6), '0x0000000000000000000000000000000000000000');

            });

            it('should log energy again (certificate #7)', async () => {

                const tx = await assetRegistry.saveSmartMeterRead(
                    0,
                    600,
                    false,
                    'lastSmartMeterReadFileHash',
                    600,
                    false,
                    { privateKey: assetSmartmeterPK });

                const event = (await assetRegistry.getAllLogNewMeterReadEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber }))[0];

                assert.equal(event.event, 'LogNewMeterRead');
                assert.deepEqual(event.returnValues, {
                    0: '0',
                    1: '500',
                    2: '600',
                    3: false,
                    4: '100',
                    5: '500',
                    6: '600',
                    7: false,
                    _assetId: '0',
                    _oldMeterRead: '500',
                    _newMeterRead: '600',
                    _smartMeterDown: false,
                    _certificatesCreatedForWh: '100',
                    _oldCO2OffsetReading: '500',
                    _newCO2OffsetReading: '600',
                    _serviceDown: false,
                });

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '7',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '7',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 8);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 3);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 2);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 3);
            });

            it('should transfer without data certificate #7 as matcher', async () => {

                assert.equal(await certificateLogic.getApproved(7), '0x0000000000000000000000000000000000000000');

                const tx = await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 7, '0x01', { privateKey: matcherPK });
                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: testreceiver.web3Contract._address,
                        2: '7',
                        _from: accountAssetOwner,
                        _to: testreceiver.web3Contract._address,
                        _tokenId: '7',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 8);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 2);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 4);
                assert.equal(await certificateLogic.getApproved(7), '0x0000000000000000000000000000000000000000');

            });

            it('should log energy again (certificate #8)', async () => {

                const tx = await assetRegistry.saveSmartMeterRead(
                    0,
                    700,
                    false,
                    'lastSmartMeterReadFileHash',
                    700,
                    false,
                    { privateKey: assetSmartmeterPK });

                const event = (await assetRegistry.getAllLogNewMeterReadEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber }))[0];

                assert.equal(event.event, 'LogNewMeterRead');
                assert.deepEqual(event.returnValues, {
                    0: '0',
                    1: '600',
                    2: '700',
                    3: false,
                    4: '100',
                    5: '600',
                    6: '700',
                    7: false,
                    _assetId: '0',
                    _oldMeterRead: '600',
                    _newMeterRead: '700',
                    _smartMeterDown: false,
                    _certificatesCreatedForWh: '100',
                    _oldCO2OffsetReading: '600',
                    _newCO2OffsetReading: '700',
                    _serviceDown: false,
                });

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '8',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '8',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 9);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 3);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 2);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 4);
            });

            it('should throw trying to transfer old certificate#8 with new matcher but missing role', async () => {

                let failed = false;
                try {
                    await certificateLogic.transferFrom(accountAssetOwner, accountTrader, 8, { privateKey: approvedPK });

                } catch (ex) {
                    failed = true;
                    if (isGanache) {
                        assert.include(ex.message, 'revert user does not have the required role');
                    }
                }
                assert.isTrue(failed);
            });

            it('should throw trying to safeTransferFrom without data old certificate#8 with new approvedAccount but missing role', async () => {

                let failed = false;
                try {
                    const tx = await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 8, null, { privateKey: approvedPK });

                } catch (ex) {
                    failed = true;
                    if (isGanache) {
                        assert.include(ex.message, 'revert user does not have the required role');
                    }
                }
                assert.isTrue(failed);
            });

            it('should throw trying to safeTransferFrom with data old certificate#8 with new approvedAccount but missing role', async () => {

                let failed = false;
                try {
                    const tx = await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 8, '0x01', { privateKey: approvedPK });

                } catch (ex) {
                    failed = true;
                    if (isGanache) {
                        assert.include(ex.message, 'revert user does not have the required role');
                    }
                }
                assert.isTrue(failed);
            });

            it('should set approvedAccount roles', async () => {
                await userLogic.setUser(approvedAccount, 'approvedAccount', { privateKey: privateKeyDeployment });
                await userLogic.setRoles(approvedAccount, 16, { privateKey: privateKeyDeployment });
            });

            it('should transfer certificate#8 with approved account', async () => {

                assert.equal(await certificateLogic.getApproved(8), '0x0000000000000000000000000000000000000000');

                const tx = await certificateLogic.transferFrom(accountAssetOwner, accountTrader, 8, { privateKey: approvedPK });
                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: accountTrader,
                        2: '8',
                        _from: accountAssetOwner,
                        _to: accountTrader,
                        _tokenId: '8',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 9);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 3);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 4);
                assert.equal(await certificateLogic.getApproved(8), '0x0000000000000000000000000000000000000000');
            });

            it('should log energy again (certificate #9)', async () => {

                const tx = await assetRegistry.saveSmartMeterRead(
                    0,
                    800,
                    false,
                    'lastSmartMeterReadFileHash',
                    800,
                    false,
                    { privateKey: assetSmartmeterPK });

                const event = (await assetRegistry.getAllLogNewMeterReadEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber }))[0];

                assert.equal(event.event, 'LogNewMeterRead');
                assert.deepEqual(event.returnValues, {
                    0: '0',
                    1: '700',
                    2: '800',
                    3: false,
                    4: '100',
                    5: '700',
                    6: '800',
                    7: false,
                    _assetId: '0',
                    _oldMeterRead: '700',
                    _newMeterRead: '800',
                    _smartMeterDown: false,
                    _certificatesCreatedForWh: '100',
                    _oldCO2OffsetReading: '700',
                    _newCO2OffsetReading: '800',
                    _serviceDown: false,
                });

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '9',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '9',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 10);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 3);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 3);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 4);
            });

            it('should safeTransferFrom without data certificate #9 as approved', async () => {

                assert.equal(await certificateLogic.getApproved(9), '0x0000000000000000000000000000000000000000');

                const tx = await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 9, null, { privateKey: approvedPK });
                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: testreceiver.web3Contract._address,
                        2: '9',
                        _from: accountAssetOwner,
                        _to: testreceiver.web3Contract._address,
                        _tokenId: '9',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 10);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 3);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 5);
                assert.equal(await certificateLogic.getApproved(9), '0x0000000000000000000000000000000000000000');

            });

            it('should log energy again (certificate #10)', async () => {

                const tx = await assetRegistry.saveSmartMeterRead(
                    0,
                    900,
                    false,
                    'lastSmartMeterReadFileHash',
                    900,
                    false,
                    { privateKey: assetSmartmeterPK });

                const event = (await assetRegistry.getAllLogNewMeterReadEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber }))[0];

                assert.equal(event.event, 'LogNewMeterRead');
                assert.deepEqual(event.returnValues, {
                    0: '0',
                    1: '800',
                    2: '900',
                    3: false,
                    4: '100',
                    5: '800',
                    6: '900',
                    7: false,
                    _assetId: '0',
                    _oldMeterRead: '800',
                    _newMeterRead: '900',
                    _smartMeterDown: false,
                    _certificatesCreatedForWh: '100',
                    _oldCO2OffsetReading: '800',
                    _newCO2OffsetReading: '900',
                    _serviceDown: false,
                });

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '10',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '10',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 11);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 3);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 3);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 5);
            });

            it('should safeTransferFrom with data certificate #10 as approved', async () => {

                assert.equal(await certificateLogic.getApproved(10), '0x0000000000000000000000000000000000000000');

                const tx = await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 10, '0x01', { privateKey: approvedPK });
                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: testreceiver.web3Contract._address,
                        2: '10',
                        _from: accountAssetOwner,
                        _to: testreceiver.web3Contract._address,
                        _tokenId: '10',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 11);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 3);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 6);
                assert.equal(await certificateLogic.getApproved(9), '0x0000000000000000000000000000000000000000');

            });

            it('should log energy again (certificate #11)', async () => {

                const tx = await assetRegistry.saveSmartMeterRead(
                    0,
                    1000,
                    false,
                    'lastSmartMeterReadFileHash',
                    1000,
                    false,
                    { privateKey: assetSmartmeterPK });

                const event = (await assetRegistry.getAllLogNewMeterReadEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber }))[0];

                assert.equal(event.event, 'LogNewMeterRead');
                assert.deepEqual(event.returnValues, {
                    0: '0',
                    1: '900',
                    2: '1000',
                    3: false,
                    4: '100',
                    5: '900',
                    6: '1000',
                    7: false,
                    _assetId: '0',
                    _oldMeterRead: '900',
                    _newMeterRead: '1000',
                    _smartMeterDown: false,
                    _certificatesCreatedForWh: '100',
                    _oldCO2OffsetReading: '900',
                    _newCO2OffsetReading: '1000',
                    _serviceDown: false,
                });

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '11',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '11',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 12);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 3);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 3);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 6);
            });

            it('should fail when trying to approve cert#11 as admin', async () => {

                let failed = false;
                try {
                    await certificateLogic.approve(approvedAccount, 11, { privateKey: privateKeyDeployment });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should fail when trying to approve cert#11 as trader', async () => {

                let failed = false;
                try {
                    await certificateLogic.approve(approvedAccount, 11, { privateKey: traderPK });
                } catch (ex) {
                    failed = true;
                }

                assert.isTrue(failed);
            });

            it('should be able to approve as cert-owner', async () => {

                const tx = await certificateLogic.approve(approvedAccount, 11, { privateKey: assetOwnerPK });

                if (isGanache) {
                    const allApprovedEvents = await certificateLogic.getAllApprovalEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allApprovedEvents.length, 1);
                    assert.equal(allApprovedEvents[0].event, 'Approval');
                    assert.deepEqual(allApprovedEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: approvedAccount,
                        2: '11',
                        _owner: accountAssetOwner,
                        _approved: approvedAccount,
                        _tokenId: '11',
                    });
                }
            });

            it('should call transferFrom with cert#11 with approved account', async () => {

                assert.equal(await certificateLogic.getApproved(11), approvedAccount);

                const tx = await certificateLogic.transferFrom(accountAssetOwner, accountTrader, 11, { privateKey: approvedPK });
                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: accountTrader,
                        2: '11',
                        _from: accountAssetOwner,
                        _to: accountTrader,
                        _tokenId: '11',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 12);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 4);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 6);
                assert.equal(await certificateLogic.getApproved(11), '0x0000000000000000000000000000000000000000');
            });

            it('should log energy again (certificate #12)', async () => {

                const tx = await assetRegistry.saveSmartMeterRead(
                    0,
                    1100,
                    false,
                    'lastSmartMeterReadFileHash',
                    1100,
                    false,
                    { privateKey: assetSmartmeterPK });

                const event = (await assetRegistry.getAllLogNewMeterReadEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber }))[0];

                assert.equal(event.event, 'LogNewMeterRead');
                assert.deepEqual(event.returnValues, {
                    0: '0',
                    1: '1000',
                    2: '1100',
                    3: false,
                    4: '100',
                    5: '1000',
                    6: '1100',
                    7: false,
                    _assetId: '0',
                    _oldMeterRead: '1000',
                    _newMeterRead: '1100',
                    _smartMeterDown: false,
                    _certificatesCreatedForWh: '100',
                    _oldCO2OffsetReading: '1000',
                    _newCO2OffsetReading: '1100',
                    _serviceDown: false,
                });

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '12',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '12',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 13);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 3);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 4);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 6);
            });

            it('should be able to approve cert#12 as cert-owner', async () => {

                const tx = await certificateLogic.approve(approvedAccount, 12, { privateKey: assetOwnerPK });

                if (isGanache) {
                    const allApprovedEvents = await certificateLogic.getAllApprovalEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allApprovedEvents.length, 1);
                    assert.equal(allApprovedEvents[0].event, 'Approval');
                    assert.deepEqual(allApprovedEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: approvedAccount,
                        2: '12',
                        _owner: accountAssetOwner,
                        _approved: approvedAccount,
                        _tokenId: '12',
                    });
                }
            });

            it('should safeTransferFrom withut data certificate #12 as approved', async () => {

                assert.equal(await certificateLogic.getApproved(12), approvedAccount);

                const tx = await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 12, null, { privateKey: approvedPK });
                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: testreceiver.web3Contract._address,
                        2: '12',
                        _from: accountAssetOwner,
                        _to: testreceiver.web3Contract._address,
                        _tokenId: '12',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 13);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 4);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 7);
                assert.equal(await certificateLogic.getApproved(9), '0x0000000000000000000000000000000000000000');

            });

            it('should log energy again (certificate #13)', async () => {

                const tx = await assetRegistry.saveSmartMeterRead(
                    0,
                    1200,
                    false,
                    'lastSmartMeterReadFileHash',
                    1200,
                    false,
                    { privateKey: assetSmartmeterPK });

                const event = (await assetRegistry.getAllLogNewMeterReadEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber }))[0];

                assert.equal(event.event, 'LogNewMeterRead');
                assert.deepEqual(event.returnValues, {
                    0: '0',
                    1: '1100',
                    2: '1200',
                    3: false,
                    4: '100',
                    5: '1100',
                    6: '1200',
                    7: false,
                    _assetId: '0',
                    _oldMeterRead: '1100',
                    _newMeterRead: '1200',
                    _smartMeterDown: false,
                    _certificatesCreatedForWh: '100',
                    _oldCO2OffsetReading: '1100',
                    _newCO2OffsetReading: '1200',
                    _serviceDown: false,
                });

                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: '0x0000000000000000000000000000000000000000',
                        1: accountAssetOwner,
                        2: '13',
                        _from: '0x0000000000000000000000000000000000000000',
                        _to: accountAssetOwner,
                        _tokenId: '13',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 14);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 3);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 4);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 7);
            });

            it('should be able to approve cert#13 as cert-owner', async () => {

                const tx = await certificateLogic.approve(approvedAccount, 13, { privateKey: assetOwnerPK });

                if (isGanache) {
                    const allApprovedEvents = await certificateLogic.getAllApprovalEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allApprovedEvents.length, 1);
                    assert.equal(allApprovedEvents[0].event, 'Approval');
                    assert.deepEqual(allApprovedEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: approvedAccount,
                        2: '13',
                        _owner: accountAssetOwner,
                        _approved: approvedAccount,
                        _tokenId: '13',
                    });
                }
            });

            it('should safeTransferFrom withut data certificate #13 as approved', async () => {

                assert.equal(await certificateLogic.getApproved(13), approvedAccount);

                const tx = await certificateLogic.safeTransferFrom(accountAssetOwner, testreceiver.web3Contract._address, 13, null, { privateKey: approvedPK });
                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: accountAssetOwner,
                        1: testreceiver.web3Contract._address,
                        2: '13',
                        _from: accountAssetOwner,
                        _to: testreceiver.web3Contract._address,
                        _tokenId: '13',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 14);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 4);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 8);
                assert.equal(await certificateLogic.getApproved(13), '0x0000000000000000000000000000000000000000');

            });

            it('should be able to burn (to = 0x0) a certificate', async () => {

                const tx = await certificateLogic.transferFrom(accountTrader, '0x0000000000000000000000000000000000000000', 11, { privateKey: traderPK });
                if (isGanache) {
                    const allTransferEvents = await certificateLogic.getAllTransferEvents({ fromBlock: tx.blockNumber, toBlock: tx.blockNumber });

                    assert.equal(allTransferEvents.length, 1);

                    assert.equal(allTransferEvents.length, 1);
                    assert.equal(allTransferEvents[0].event, 'Transfer');
                    assert.deepEqual(allTransferEvents[0].returnValues, {
                        0: accountTrader,
                        1: '0x0000000000000000000000000000000000000000',
                        2: '11',
                        _from: accountTrader,
                        _to: '0x0000000000000000000000000000000000000000',
                        _tokenId: '11',
                    });
                }
                assert.equal(await certificateLogic.getCertificateListLength(), 14);
                assert.equal(await certificateLogic.balanceOf(accountAssetOwner), 2);
                assert.equal(await certificateLogic.balanceOf(accountTrader), 3);
                assert.equal(await certificateLogic.balanceOf(testreceiver.web3Contract._address), 8);
                assert.equal(await certificateLogic.getApproved(13), '0x0000000000000000000000000000000000000000');
            });
        });
    });
});