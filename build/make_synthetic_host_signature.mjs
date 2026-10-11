// R74 test helper ONLY: generate ephemeral in-memory Ed25519 key and sign a supplied test message.
// Never writes a private key, never enrolls into the production trust registry.
import crypto from 'node:crypto';
import fs from 'node:fs';
const data=JSON.parse(fs.readFileSync(0,'utf8'));
const {publicKey,privateKey}=crypto.generateKeyPairSync('ed25519');
const message=Buffer.from(data.MessageBase64,'base64');
const signature=crypto.sign(null,message,privateKey);
process.stdout.write(JSON.stringify({PublicKeyPem:publicKey.export({format:'pem',type:'spki'}),SignatureBase64:signature.toString('base64')}));
