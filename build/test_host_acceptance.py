#!/usr/bin/env python3
"""R74 offline-only cryptographic witness & hostile fixture regression (no Windows mutations)."""
from __future__ import annotations
import base64,copy,hashlib,io,json,pathlib,subprocess,tempfile,zipfile
from verify_host_acceptance import verify_bundle
HERE=pathlib.Path(__file__).resolve().parent
SHA="a"*40
MAIN="b"*64
BASEMAIN="05F9E069C4598FDAD327A41BF1CA34A1498D022119DB81E09F4B3B091C9BA377"
BASECONFIG="0E397F5EC24A8243EB6AD996923FECAFA6D8500B80B5CECAA6BCC4466DF72650"
EIGHT=("startup","hover","hardware","temperature","protected-sensor-health","support","start-search","explorer-recovery")
def digest(b):return hashlib.sha256(b).hexdigest().upper()
def js(o):return (json.dumps(o,sort_keys=True,separators=(",",":"),ensure_ascii=False)+"\n").encode()
def fixture(gate,tmp,change=None):
    raw={}
    statement={"Schema":2,"Gate":gate,"SourceSHA":SHA,"HostRole":"DISPOSABLE_WINDOWS_VALIDATION",
    "HostID":"EPHEMERAL-TEST-VM-001","IndependentlyAuthorized":True,
    "RealProductInvoked":True,"WitnessPurpose":"INDEPENDENT_G13_G14_ACCEPTANCE"}
    if gate=="G13":
        state={"BeforeBackgroundType":0,"AfterBackgroundType":0,
        "BeforeRegistry":{"WallpaperPath":"C:\\Test\\Picture.jpg","WallpaperStyle":"10","TileWallpaper":"0"},
        "AfterRegistry":{"WallpaperPath":"C:\\Test\\Picture.jpg","WallpaperStyle":"10","TileWallpaper":"0"}}
        raw.update({"raw/wallpaper/before.bin":b"picture-before","raw/wallpaper/restored.bin":b"picture-before",
          "raw/wallpaper/applied.bin":b"picture-temporary",
          "raw/wallpaper/product-events.json":js({"ProductClass":"WallpaperStudio","ApplyDesktopInvoked":True,
            "RestoreDesktopPreStateInvoked":True,"IndependentAfterStateObserved":True,"ProcessId":1234})})
        state.update({"BeforeImageSHA256":digest(raw["raw/wallpaper/before.bin"]),
                      "AppliedImageSHA256":digest(raw["raw/wallpaper/applied.bin"]),
                      "AfterImageSHA256":digest(raw["raw/wallpaper/restored.bin"])})
        statement["State"]=state
    else:
        for name in EIGHT:
            raw["raw/probes/"+name+".json"]=js({"Name":name,"Status":"PASS","RealInstalledProcess":True,
             "ProcessId":1234,"NativeObservationCount":8})
        raw["raw/rollback/actual-prepost.json"]=js({"Status":"PASS","ObservedInstalledApp":True,"RollbackActual":True})
        statement.update({"Probes":[{"Name":p,"Status":"PASS"} for p in EIGHT],
         "InstalledMainSHA256":MAIN,"ActualSignedSetupExecuted":True,
         "SignedSetupSHA256":"e"*64,
         "Rollback":{"OriginalMainSHA256":BASEMAIN,"OriginalConfigSHA256":BASECONFIG,
           "RestoredMainSHA256":BASEMAIN,"RestoredConfigSHA256":BASECONFIG,"ExplorerRecovered":True,
           "SensorsHealthy":True,"ProtectedUserWallpaperIntact":True}})
    if change:change(statement,raw)
    manifest=js({"Files":[{"Path":n,"Bytes":len(d),"SHA256":digest(d)} for n,d in sorted(raw.items())]})
    statement["ManifestSHA256"]=digest(manifest)
    statement_bytes=js(statement)
    signed=subprocess.run(["node",str(HERE/"make_synthetic_host_signature.mjs")],input=json.dumps({
        "MessageBase64":base64.b64encode(statement_bytes).decode()}),text=True,capture_output=True,timeout=20,check=True)
    credentials=json.loads(signed.stdout)
    registry={"Schema":1,"TrustedWitnesses":[{"KeyId":"R74_EPHEMERAL_TEST_ONLY","Authority":"INDEPENDENT_APPROVED_LAB",
        "PublicKeyPem":credentials["PublicKeyPem"],"AllowedGates":["G13","G14"]}]}
    p=tmp/"bundle.zip"
    with zipfile.ZipFile(p,"w",compression=zipfile.ZIP_DEFLATED) as z:
        z.writestr("manifest.json",manifest)
        z.writestr("statement.json",statement_bytes)
        z.writestr("witness-signature.bin",base64.b64decode(credentials["SignatureBase64"]))
        for n,d in raw.items():z.writestr(n,d)
    receipt={"Schema":2,"Gate":gate,"SourceSHA":SHA,"BundlePath":str(p),"BundleSHA256":digest(p.read_bytes()),
        "StatementSHA256":digest(statement_bytes),"WitnessKeyId":"R74_EPHEMERAL_TEST_ONLY"}
    rp=tmp/"receipt.json";rp.write_bytes(js(receipt))
    tp=tmp/"trust.json";tp.write_bytes(js(registry))
    return rp,tp,p
out=[]
def test(name,gate,change=None,post=None,allowed=False):
    with tempfile.TemporaryDirectory() as d:
        root=pathlib.Path(d)
        rp,tp,bundle=fixture(gate,root,change=change)
        if post:post(rp,tp,bundle)
        try:verdict=verify_bundle(gate,rp,SHA,MAIN,tp)
        except (ValueError,KeyError,TypeError,zipfile.BadZipFile,RuntimeError,subprocess.TimeoutExpired) as e:
            if allowed:raise RuntimeError("POSITIVE_BLOCKED_"+name+":"+str(e))
            out.append({"Name":name,"Result":"BLOCKED","Reason":str(e)[:120]})
        else:
            if not allowed:raise RuntimeError("FALSE_ACCEPTED_"+name)
            assert verdict["Status"]=="PASS_INDEPENDENT_SIGNED_HOST_EVIDENCE"
            out.append({"Name":name,"Result":"PASS_SYNTHETIC_ONLY"})
test("G13_VALID_SIGNED_EPHEMERAL", "G13",allowed=True)
test("G14_VALID_SIGNED_EPHEMERAL", "G14",allowed=True)
test("G13_SLIDESHOW_FORBIDDEN","G13",lambda s,r:s["State"].__setitem__("BeforeBackgroundType",2))
test("G13_AFTER_SLIDESHOW","G13",lambda s,r:s["State"].__setitem__("AfterBackgroundType",2))
test("G13_RESTORE_NOT_SAME","G13",lambda s,r:r.__setitem__("raw/wallpaper/restored.bin",b"not-the-original"))
test("G13_APPLIED_NOT_DISTINCT","G13",lambda s,r:r.__setitem__("raw/wallpaper/applied.bin",b"picture-before"))
test("G13_REGISTRY_PATH_CHANGED","G13",lambda s,r:s["State"]["AfterRegistry"].__setitem__("WallpaperPath","C:\\Changed.jpg"))
test("G13_NOT_REAL_PRODUCT","G13",lambda s,r:s.__setitem__("RealProductInvoked",False))
test("G13_UNAUTHORIZED_HOST","G13",lambda s,r:s.__setitem__("IndependentlyAuthorized",False))
test("G13_PERSONAL_HOST_FORBIDDEN","G13",lambda s,r:s.__setitem__("HostID","EMAD-PC-ULTIMAT"))
test("G13_PRODUCT_EVENTS_FAKE","G13",lambda s,r:r.__setitem__("raw/wallpaper/product-events.json",js({"Status":"PASS"})))
test("G14_MISSING_EIGHTH","G14",lambda s,r:s["Probes"].pop())
test("G14_INVALID_ONE_PROBE","G14",lambda s,r:r.__setitem__("raw/probes/start-search.json",js({"Status":"PASS"})))
test("G14_INSTALLED_MAIN_WRONG","G14",lambda s,r:s.__setitem__("InstalledMainSHA256","a"*64))
test("G14_ROLLBACK_NOT_EXACT","G14",lambda s,r:s["Rollback"].__setitem__("RestoredConfigSHA256","0"*64))
test("G14_EXPLORER_NOT_RECOVERED","G14",lambda s,r:s["Rollback"].__setitem__("ExplorerRecovered",False))
test("G14_UNSIGNED_SETUP","G14",lambda s,r:s.__setitem__("ActualSignedSetupExecuted",False))
test("G14_NO_RAW_ROLLBACK","G14",lambda s,r:r.pop("raw/rollback/actual-prepost.json"))
def remove_trust(rp,tp,bundle):
    d=json.loads(tp.read_text());d["TrustedWitnesses"]=[];tp.write_bytes(js(d))
test("G13_NO_ENROLLED_WITNESS","G13",post=remove_trust)
def wrong_receipt_sha(rp,tp,bundle):
    d=json.loads(rp.read_text());d["BundleSHA256"]="0"*64;rp.write_bytes(js(d))
test("G14_BUNDLE_SHA_TAMPER","G14",post=wrong_receipt_sha)
def corrupted_signature(rp,tp,bundle):
    with zipfile.ZipFile(bundle) as z:files={n:z.read(n) for n in z.namelist()}
    files["witness-signature.bin"]=b"\0"*64
    with zipfile.ZipFile(bundle,"w",zipfile.ZIP_DEFLATED) as z:
        for n,d in files.items():z.writestr(n,d)
    d=json.loads(rp.read_text());d["BundleSHA256"]=digest(bundle.read_bytes());rp.write_bytes(js(d))
test("G13_FAKE_SIGNED_BYTES","G13",post=corrupted_signature)
def generic_json_forgery(rp,tp,bundle):
    rp.write_bytes(js({"Status":"PASS","Gate":"G14","SourceSHA":SHA,"AllTestsPassed":True}))
test("G14_ONLY_PASS_BOOLEANS","G14",post=generic_json_forgery)
def source_mismatch(rp,tp,bundle):
    d=json.loads(rp.read_text());d["SourceSHA"]="0"*40;rp.write_bytes(js(d))
test("G13_WRONG_SOURCE","G13",post=source_mismatch)
def unexpected_zip_entry(rp,tp,bundle):
    with zipfile.ZipFile(bundle) as z: old={n:z.read(n) for n in z.namelist()}
    old["hidden_unmanifested.txt"]=b"not in signed manifest"
    with zipfile.ZipFile(bundle,"w",zipfile.ZIP_DEFLATED) as z:
        for n,d in old.items(): z.writestr(n,d)
    receipt=json.loads(rp.read_text());receipt["BundleSHA256"]=digest(bundle.read_bytes());rp.write_bytes(js(receipt))
test("G14_EXTRANEOUS_ZIP_ENTRY","G14",post=unexpected_zip_entry)
result={"Revision":"R74","Status":"PASS" if len(out)==24 and sum(x["Result"]=="BLOCKED" for x in out)==22 else "FAIL",
        "PositiveSynthetic":sum(x["Result"]=="PASS_SYNTHETIC_ONLY" for x in out),
        "AdversarialRejected":sum(x["Result"]=="BLOCKED" for x in out),
        "Total":len(out),"ProductionTrustRegistry":"EMPTY_NO_AUTHORIZED_LAB_KEY",
        "LiveG13":"NOT_ATTEMPTED","LiveG14":"NOT_ATTEMPTED",
        "Cases":out}
print(json.dumps({k:v for k,v in result.items() if k!="Cases"},sort_keys=True))
if result["Status"]!="PASS":raise SystemExit(45)
