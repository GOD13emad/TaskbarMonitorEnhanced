// R74: verify detached Ed25519 witness attestation. No signer private key in production.
import fs from 'node:fs';
import crypto from 'node:crypto';
function fail(){ process.stdout.write('WITNESS_SIGNATURE_BLOCKED\n'); process.exitCode=45; }
try {
  if(process.argv.length!==3) throw Error('ARGS');
  const registry=JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const request=JSON.parse(fs.readFileSync(0,'utf8'));
  if(!request || !registry || registry.Schema!==1 || !Array.isArray(registry.TrustedWitnesses)) throw Error('INVALID_INPUT');
  const keys=registry.TrustedWitnesses.filter(k=>k.KeyId===request.KeyId && k.Authority==='INDEPENDENT_APPROVED_LAB');
  if(keys.length!==1) throw Error('UNTRUSTED');
  const pub=crypto.createPublicKey(keys[0].PublicKeyPem);
  if(pub.asymmetricKeyType!=='ed25519') throw Error('WRONG_KEY_TYPE');
  const msg=Buffer.from(request.MessageBase64, 'base64');
  const sig=Buffer.from(request.SignatureBase64, 'base64');
  if(sig.length!==64 || msg.length===0 || msg.length>256000) throw Error('SIZE');
  if(!crypto.verify(null,msg,pub,sig)) throw Error('INVALID_SIGNATURE');
  process.stdout.write('WITNESS_SIGNATURE_VALID\n');
} catch (_) {fail();}
