import { Sloffle } from 'sloffle';
import * as fs from 'fs';
import * as path from 'path';
import { Web3Type } from '../types/web3';
import { OriginContractLookup } from '../wrappedContracts/OriginContractLookup';
import { AssetContractLookup } from 'ew-asset-registry-contracts';

export async function migrateCertificateRegistryContracts(
    web3: Web3Type,
    assetContractLookupAddress: string,
): Promise<JSON> {
    return new Promise<any>(async (resolve, reject) => {

        const configFile = JSON.parse(fs.readFileSync(process.cwd() + '/connection-config.json', 'utf8'));

        const sloffle = new Sloffle((web3 as any));

        const privateKeyDeployment = configFile.develop.deployKey.startsWith('0x') ?
            configFile.develop.deployKey : '0x' + configFile.develop.deployKey;
        const accountDeployment = web3.eth.accounts.privateKeyToAccount(privateKeyDeployment).address;

        const originContractLookupWeb3 = await sloffle.deploy(
            path.resolve(__dirname, '../../contracts/OriginContractLookup.json'),
            [],
            { privateKey: privateKeyDeployment },
        );

        const certificateLogicWeb3 = await sloffle.deploy(
            path.resolve(__dirname, '../../contracts/CertificateLogic.json'),
            [assetContractLookupAddress, originContractLookupWeb3._address],
            { privateKey: privateKeyDeployment },
        );

        const certificateDBWeb3 = await sloffle.deploy(
            path.resolve(__dirname, '../../contracts/CertificateDB.json'),
            [certificateLogicWeb3._address],
            { privateKey: privateKeyDeployment },
        );

        const originContractLookup: OriginContractLookup
            = new OriginContractLookup((web3 as any), originContractLookupWeb3._address);

        await originContractLookup.init(
            assetContractLookupAddress,
            certificateLogicWeb3._address,
            certificateDBWeb3._address,
            { privateKey: privateKeyDeployment });

        resolve(sloffle.deployedContracts);
    });
}

export async function migrateEnergyBundleContracts(
    web3: Web3Type,
    assetContractLookupAddress: string,
): Promise<JSON> {
    return new Promise<any>(async (resolve, reject) => {

        const configFile = JSON.parse(fs.readFileSync(process.cwd() + '/connection-config.json', 'utf8'));

        const sloffle = new Sloffle((web3 as any));

        const privateKeyDeployment = configFile.develop.deployKey.startsWith('0x') ?
            configFile.develop.deployKey : '0x' + configFile.develop.deployKey;

        const originContractLookupWeb3 = await sloffle.deploy(
            path.resolve(__dirname, '../../contracts/OriginContractLookup.json'),
            [],
            { privateKey: privateKeyDeployment },
        );

        const energyCertificateBundleLogicWeb3 = await sloffle.deploy(
            path.resolve(__dirname, '../../contracts/EnergyCertificateBundleLogic.json'),
            [assetContractLookupAddress, originContractLookupWeb3._address],
            { privateKey: privateKeyDeployment },
        );

        const energyCertificateBundleDBWeb3 = await sloffle.deploy(
            path.resolve(__dirname, '../../contracts/EnergyCertificateBundleDB.json'),
            [energyCertificateBundleLogicWeb3._address],
            { privateKey: privateKeyDeployment },
        );

        const originContractLookup: OriginContractLookup
            = new OriginContractLookup((web3 as any), originContractLookupWeb3._address);

        await originContractLookup.init(
            assetContractLookupAddress,
            energyCertificateBundleLogicWeb3._address,
            energyCertificateBundleDBWeb3._address,
            { privateKey: privateKeyDeployment });

        resolve(sloffle.deployedContracts);
    });
}
