#!/usr/bin/env python3
"""R74 G13/G14 independent-host witness-gated acceptance evidence.
No production trust keys are provisioned by this source. A trusted test-lab key
must be deliberately enrolled through a separately reviewed change; otherwise
G13/G14 ALWAYS BLOCK. This tool never executes Setup or changes Wallpaper.
"""
from __future__ import annotations
import argparse,base64,hashlib,json,os,pathlib,re,subprocess,sys,zipfile
ROOT=pathlib.Path(__file__).resolve().parent.parent
TRUST=ROOT/"build"/"host_acceptance_trust.json"
CRYPTO=ROOT/"build"/"host_acceptance_signature.mjs"
MAX_ZIP=72*1024*1024
MAX_ENTRY=32*1024*1024
MAX_FILES=80
HEX64=r"[0-9A-Fa-f]{64}"
HEX40=r"[0-9a-fA-F]{40}"
def required(cond,why):
    if not cond:raise ValueError("G13G14_REJECT_"+why)
def sha(data):return hashlib.sha256(data).hexdigest().upper()
def hex64(x):return isinstance(x,str) and re.fullmatch(HEX64,x) is not None
def source_check(s):return isinstance(s,str) and re.fullmatch(HEX40,s) is not None
def parse_json(b,maxsize=256000):
    required(isinstance(b,bytes) and 0<len(b)<=maxsize,"JSON_SIZE")
    return json.loads(b.decode("utf-8-sig"))
def check_statement(gate,s,files,source,expected_main,manifest):
    required(isinstance(s,dict) and s.get("Schema")==2 and s.get("Gate")==gate,"STATEMENT_SCHEMA")
    required(s.get("SourceSHA")==source,"SOURCE_DRIFT")
    required(s.get("HostRole")=="DISPOSABLE_WINDOWS_VALIDATION" and s.get("HostID") not in ("EMAD-PC-ULTIMAT","saeid",""),"UNTRUSTED_HOST_ROLE")
    required(s.get("IndependentlyAuthorized") is True and s.get("RealProductInvoked") is True,"NO_ACTUAL_AUTHORIZED_PRODUCT")
    required(s.get("WitnessPurpose")=="INDEPENDENT_G13_G14_ACCEPTANCE","WITNESS_PURPOSE")
    required(s.get("ManifestSHA256")==sha(manifest),"MANIFEST_NOT_SIGNED")
    paths=set(files)
    if gate=="G13":
        state=s.get("State",{})
        required(state.get("BeforeBackgroundType")==0 and state.get("AfterBackgroundType")==0,"NOT_STATIC_PICTURE")
        required(state.get("BeforeRegistry")==state.get("AfterRegistry") and isinstance(state.get("BeforeRegistry"),dict),"REGISTRY_STATE_DRIFT")
        for k in ("WallpaperPath","WallpaperStyle","TileWallpaper"):
            required(isinstance(state["BeforeRegistry"].get(k),str),"REGISTRY_FIELD_"+k)
        before="raw/wallpaper/before.bin"
        applied="raw/wallpaper/applied.bin"
        after="raw/wallpaper/restored.bin"
        required({before,applied,after,"raw/wallpaper/product-events.json"}.issubset(paths),"MISSING_G13_RAW")
        required(sha(files[before])==sha(files[after]) and sha(files[before])!=sha(files[applied]),"IMAGE_RESTORE_HASH")
        evidence=parse_json(files["raw/wallpaper/product-events.json"])
        required(evidence.get("ProductClass")=="WallpaperStudio" and evidence.get("ApplyDesktopInvoked") is True
                 and evidence.get("RestoreDesktopPreStateInvoked") is True
                 and evidence.get("IndependentAfterStateObserved") is True
                 and isinstance(evidence.get("ProcessId"),int) and evidence["ProcessId"]>0,"G13_PRODUCT_TRACE")
        required(state.get("BeforeImageSHA256")==sha(files[before]) and state.get("AfterImageSHA256")==sha(files[after])
                 and state.get("AppliedImageSHA256")==sha(files[applied]),"G13_WRONG_IMAGE_FIELD")
    elif gate=="G14":
        expected=("startup","hover","hardware","temperature","protected-sensor-health","support","start-search","explorer-recovery")
        probes=s.get("Probes",[])
        required(isinstance(probes,list) and len(probes)==8 and set(x.get("Name") for x in probes)==set(expected),"EIGHT_PROBES")
        for p in probes:
            name=p["Name"];path="raw/probes/"+name+".json"
            required(path in files and p.get("Status")=="PASS","G14_PROBE_"+name)
            raw=parse_json(files[path])
            required(raw.get("Name")==name and raw.get("Status")=="PASS"
                and raw.get("RealInstalledProcess") is True
                and isinstance(raw.get("ProcessId"),int) and raw["ProcessId"]>0
                and isinstance(raw.get("NativeObservationCount"),int) and raw["NativeObservationCount"]>0,"G14_RAW_PROBE_"+name)
        rollback=s.get("Rollback",{})
        required(rollback.get("OriginalMainSHA256")=="05F9E069C4598FDAD327A41BF1CA34A1498D022119DB81E09F4B3B091C9BA377"
          and rollback.get("OriginalConfigSHA256")=="0E397F5EC24A8243EB6AD996923FECAFA6D8500B80B5CECAA6BCC4466DF72650"
          and rollback.get("RestoredMainSHA256")==rollback.get("OriginalMainSHA256")
          and rollback.get("RestoredConfigSHA256")==rollback.get("OriginalConfigSHA256")
          and rollback.get("ExplorerRecovered") is True and rollback.get("SensorsHealthy") is True
          and rollback.get("ProtectedUserWallpaperIntact") is True,"G14_ROLLBACK_NOT_PROVEN")
        required(s.get("InstalledMainSHA256")==expected_main and hex64(expected_main),"G14_SIGNED_MAIN_SHA")
        required(s.get("ActualSignedSetupExecuted") is True and hex64(s.get("SignedSetupSHA256")),"G14_SIGNED_SETUP_UNVERIFIED")
        required("raw/rollback/actual-prepost.json" in files,"G14_NO_ROLLBACK_TRACE")
        rb=parse_json(files["raw/rollback/actual-prepost.json"])
        required(rb.get("Status")=="PASS" and rb.get("ObservedInstalledApp") is True and rb.get("RollbackActual") is True,"G14_ROLLBACK_TRACE")
    else:required(False,"UNKNOWN_GATE")
def verify_bundle(gate,receipt_path,source,expected_main,trust_path=TRUST):
    required(gate in ("G13","G14") and source_check(source),"ARGUMENTS")
    receipt=parse_json(pathlib.Path(receipt_path).read_bytes())
    required(receipt.get("Schema")==2 and receipt.get("Gate")==gate and receipt.get("SourceSHA")==source,"RECEIPT_SCHEMA")
    required(hex64(receipt.get("BundleSHA256")) and hex64(receipt.get("StatementSHA256")),"RECEIPT_HASH")
    bundle=pathlib.Path(receipt.get("BundlePath",""))
    required(bundle.is_file() and bundle.stat().st_size<=MAX_ZIP,"BUNDLE_MISSING_OR_TOO_LARGE")
    b=bundle.read_bytes()
    required(sha(b)==receipt["BundleSHA256"].upper(),"BUNDLE_SHA")
    with zipfile.ZipFile(bundle) as z:
        names=z.namelist()
        required(len(names)<=MAX_FILES and len(names)==len(set(names)) and len(names)==len(set(n.casefold() for n in names)),"ZIP_NAMES")
        required(z.testzip() is None,"ZIP_CRC")
        required(all(not n.startswith("/") and "\\" not in n and ".." not in pathlib.PurePosixPath(n).parts for n in names),"ZIP_TRAVERSAL")
        required(set(("statement.json","manifest.json","witness-signature.bin")).issubset(names),"ZIP_CONTROLS")
        infos=z.infolist()
        required(all(x.file_size<=MAX_ENTRY for x in infos),"ZIP_BOMB_ENTRY")
        required(sum(x.file_size for x in infos)<=MAX_ZIP,"TOTAL_UNCOMPRESSED_LIMIT")
        required(all(not x.is_dir() and not (x.create_system==3 and ((x.external_attr>>16)&0o170000)==0o120000) for x in infos),"ZIP_LINK_OR_DIRECTORY")
        required(all(x.compress_size>0 or x.file_size==0 for x in infos),"ZIP_INVALID_COMPRESSED_LENGTH")
        manifest_bytes=z.read("manifest.json")
        statement_bytes=z.read("statement.json")
        signature=z.read("witness-signature.bin")
        required(sha(statement_bytes)==receipt["StatementSHA256"].upper(),"STATEMENT_SHA")
        manifest=parse_json(manifest_bytes)
        required(isinstance(manifest,dict) and isinstance(manifest.get("Files"),list),"MANIFEST_SCHEMA")
        allowed_raw={f.get("Path") for f in manifest["Files"] if isinstance(f,dict)}
        required(set(names)==allowed_raw|{"statement.json","manifest.json","witness-signature.bin"},"ZIP_EXTRA_OR_UNMANIFESTED_ENTRY")
        rawfiles={n:z.read(n) for n in names if n.startswith("raw/") and not n.endswith("/")}
        required(rawfiles and len(rawfiles)==len(manifest["Files"]),"RAW_MANIFEST_COUNT")
        required({f.get("Path") for f in manifest["Files"]}==set(rawfiles),"RAW_MANIFEST_COVERAGE")
        for item in manifest["Files"]:
            path=item["Path"];payload=rawfiles[path]
            required(hex64(item.get("SHA256")) and item["SHA256"].upper()==sha(payload)
                and item.get("Bytes")==len(payload),"RAW_MANIFEST_SHA_"+path)
        statement=parse_json(statement_bytes)
        check_statement(gate,statement,rawfiles,source,expected_main,manifest_bytes)
    trust=pathlib.Path(trust_path)
    required(trust.is_file(),"NO_APPROVED_WITNESS_KEY_REGISTRY")
    registry=parse_json(trust.read_bytes())
    required(registry.get("Schema")==1 and isinstance(registry.get("TrustedWitnesses"),list),"BAD_WITNESS_REGISTRY")
    # Registry intentionally contains zero production trust anchors until an authorized independent witness is enrolled.
    keyid=receipt.get("WitnessKeyId")
    keys=[k for k in registry["TrustedWitnesses"] if k.get("KeyId")==keyid and k.get("AllowedGates",[]) and gate in k["AllowedGates"]]
    required(len(keys)==1 and keys[0].get("Authority")=="INDEPENDENT_APPROVED_LAB","UNAPPROVED_WITNESS_KEY")
    payload={"KeyId":keyid,"MessageBase64":base64.b64encode(statement_bytes).decode(),"SignatureBase64":base64.b64encode(signature).decode()}
    call=subprocess.run(["node",str(CRYPTO),str(trust)],input=json.dumps(payload),text=True,capture_output=True,timeout=8)
    required(call.returncode==0 and call.stdout.strip()=="WITNESS_SIGNATURE_VALID","BAD_WITNESS_SIGNATURE")
    return {"Status":"PASS_INDEPENDENT_SIGNED_HOST_EVIDENCE","Gate":gate,"SourceSHA":source,
            "BundleSHA256":sha(b),"StatementSHA256":sha(statement_bytes),"WitnessKeyId":keyid,
            "NoLocalUserMutation":True,"ExternalHostOnly":True}
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--gate",required=True,choices=("G13","G14"))
    p.add_argument("--receipt",required=True)
    p.add_argument("--source",required=True)
    p.add_argument("--expected-main",default="")
    args=p.parse_args()
    try:
        answer=verify_bundle(args.gate,args.receipt,args.source,args.expected_main)
        code=0
    except Exception as e:
        answer={"Gate":args.gate,"Status":"BLOCKED_FAIL_CLOSED","Reason":str(e)[:180] if isinstance(e,ValueError) else "UNVERIFIED_HOST_EVIDENCE"}
        code=45
    print(json.dumps(answer,ensure_ascii=False,sort_keys=True))
    return code
if __name__=="__main__":sys.exit(main())
