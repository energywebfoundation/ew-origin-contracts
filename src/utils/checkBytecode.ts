import * as fs from 'fs';

const main = async () => {

    const TEFile = JSON.parse(fs.readFileSync(process.cwd() + '/dist/contracts/TradableEntityLogic.json', 'utf8'));

    const teBytecode = TEFile.bytecode;
    console.log('bytecode tradable-Entity');
    console.log('length: ' + teBytecode.length);
    console.log('KB: ' + (teBytecode.length) / 2);
    console.log('');

    const certFile = JSON.parse(fs.readFileSync(process.cwd() + '/dist/contracts/CertificateLogic.json', 'utf8'));
    const certBytecode = certFile.bytecode;

    console.log('bytecode certLogic');
    console.log('length: ' + certBytecode.length);
    console.log('KB: ' + (certBytecode.length) / 2);
    console.log('');

    const certDBFile = JSON.parse(fs.readFileSync(process.cwd() + '/dist/contracts/CertificateDB.json', 'utf8'));
    const certDBBytecode = certDBFile.bytecode;

    console.log('bytecode CertificateDB');
    console.log('length: ' + certDBBytecode.length);
    console.log('KB: ' + (certDBBytecode.length) / 2);
    console.log('');
};

main();