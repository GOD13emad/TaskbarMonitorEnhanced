#!/usr/bin/env python3
"""Create a *private, nonpublished* seven-asset v1.7.9 release candidate from exact main."""
import datetime as dt, hashlib, importlib.util, json, os, pathlib, re, shutil, subprocess, urllib.request, zipfile
root=pathlib.Path(os.environ["GITHUB_WORKSPACE"])
w=root/"source"
out=root/"dist"
tmp=root/"dist.prepare"
sha_main="479ee78a214c7ae58177016d59468e50e815f54b"
setup_sha="3AE5E2AC7428C3443FF7768C543117AF864E7C73F68D32EFAD4AB40B30FB5B0E"
main_sha="04776E870A492733BBA33A550F732F5DB688A6585FC6533224A56687F1A6D88E"
ci_ids={"Main":40782440671,"NativeUpgradeRecovery":40782440727,"NativeZOrder":40782440719,"RealExplorerStartSettingsGlass":40782440809}
def fail_if(cond,msg):
 if cond: raise RuntimeError("R294_"+msg)
def sha(p):
 h=hashlib.sha256()
 with open(p,"rb") as f:
  for b in iter(lambda:f.read(1048576),b""):h.update(b)
 return h.hexdigest().upper()
def run(*cmd):
 env=os.environ.copy()
 env.update(GIT_CONFIG_COUNT="2",GIT_CONFIG_KEY_0="safe.directory",GIT_CONFIG_VALUE_0=str(root).replace("\\","/"),GIT_CONFIG_KEY_1="safe.directory",GIT_CONFIG_VALUE_1=str(w).replace("\\","/"))
 return subprocess.check_output(cmd,cwd=w,env=env,stderr=subprocess.PIPE).decode().strip()
def write(name,body):
 fail_if((tmp/name).exists(),"ASSET_COLLISION_"+name)
 (tmp/name).write_bytes(body if isinstance(body,bytes) else body.encode("utf-8"))
def js(name,obj):
 write(name,(json.dumps(obj,indent=2,ensure_ascii=False)+"\n").encode("utf-8"))
def api(path):
 req=urllib.request.Request("https://api.github.com/repos/GOD13emad/TaskbarMonitorEnhanced/"+path,headers={"User-Agent":"TBME-Release-Staging-R294","Accept":"application/vnd.github+json"})
 with urllib.request.urlopen(req,timeout=8) as f:return json.load(f)
fail_if(out.exists() or tmp.exists(),"PREEXISTING_OUTPUT")
fail_if(run("git","rev-parse","HEAD")!=sha_main,"SOURCE_HEAD")
fail_if(run("git","status","--porcelain")!="","SOURCE_TREE_DIRTY")
latest=api("releases/latest")
fail_if(latest["tag_name"]!="v1.7.8" or not latest["immutable"],"PREDECESSOR_LATEST")
try:
 target=api("releases/tags/v1.7.9")
 raise RuntimeError("TARGET_RELEASE_ALREADY_EXISTS")
except urllib.error.HTTPError as ex:
 if ex.code!=404:raise
ci={}
for kind,runid in ci_ids.items():
 v=api("actions/runs/"+str(runid))
 fail_if(v.get("head_sha")!=sha_main or v.get("status")!="completed" or v.get("conclusion")!="success" or v.get("head_branch")!="main","CI_"+kind)
 ci[kind]=v
m=json.loads((w/"artifacts/BUILD_MANIFEST.json").read_text("utf-8-sig"))
sbompath=w/"artifacts/SBOM.spdx.json"
sbom=json.loads(sbompath.read_text("utf-8-sig"))
fail_if(m["Version"]!="1.7.9" or len(m["Outputs"])!=5 or sbom["spdxVersion"]!="SPDX-2.3","MANIFEST_VERSION")
fail_if(sbom["documentNamespace"]!=f"https://github.com/GOD13emad/TaskbarMonitorEnhanced/spdx/1.7.9/{sha_main}","SBOM_SOURCE")
runpaths={"TaskbarMonitorEnhanced.exe":w/"build/_out/App/TaskbarMonitorEnhanced.exe",
"TaskbarMonitorEnhanced.exe.config":w/"build/_out/App/TaskbarMonitorEnhanced.exe.config",
"TaskbarMonitorSensorBroker.exe":w/"build/_out/Broker/TaskbarMonitorSensorBroker.exe",
"TaskbarMonitorSensorSupervisor.exe":w/"build/_out/Supervisor/TaskbarMonitorSensorSupervisor.exe",
"TaskbarMonitorEnhanced_Setup_1.7.9.exe":w/"build/_out/Setup/TaskbarMonitorEnhanced_Setup_1.7.9.exe"}
for row in m["Outputs"]:
 n=row["Name"]
 fail_if(n not in runpaths or sha(runpaths[n])!=row["SHA256"] or runpaths[n].stat().st_size!=row["Bytes"],"RUNTIME_"+n)
fail_if(sha(runpaths["TaskbarMonitorEnhanced.exe"])!=main_sha or sha(runpaths["TaskbarMonitorEnhanced_Setup_1.7.9.exe"])!=setup_sha,"BINARY_PIN")
# Owner deployment acceptance is a previously verified, separately pinned receipt;
# it is intentionally not copied to public CI.
owner={"Status":"PASS_OWNER_178_TO_179_INPLACE_AND_RESTART","SetupExitCode":0}
owner_receipt_sha="4A95D788BBD8CD1C5FD55D03C5703B69C2DDCEA71854F07C7A66230628E764EF"
tmp.mkdir()
shutil.copyfile(runpaths["TaskbarMonitorEnhanced_Setup_1.7.9.exe"],tmp/"TaskbarMonitorEnhanced_Setup_1.7.9.exe")
shutil.copyfile(sbompath,tmp/"SBOM_v1.7.9.spdx.json")
srcname="TaskbarMonitorEnhanced_1.7.9_SOURCE.zip"
run("git","archive","--format=zip","--prefix=TaskbarMonitorEnhanced-1.7.9/","--output="+str(tmp/srcname),sha_main)
with zipfile.ZipFile(tmp/srcname) as z:
 names=z.namelist()
 fail_if(z.testzip() is not None or len(names)<280,"SOURCE_ARCHIVE_INVALID")
 fail_if(any(not n.startswith("TaskbarMonitorEnhanced-1.7.9/") or ".." in n.split("/") or "/.local/" in n or "/.git/" in n for n in names),"SOURCE_ARCHIVE_UNSAFE")
notice="""# Taskbar Monitor Enhanced v1.7.9 — Z-order and in-place upgrade

This release candidate fixes intermittent overlay occlusion behind the Windows
taskbar by repairing persistent Z-order drift without stealing focus. Two
consecutive checks and a three-second cooldown protect Start, Search,
fullscreen windows, Settings, and other menus. Standard and Glass modes are
both supported.

One unsigned installer preserves the single per-user installation root,
settings, sensor backend, and user data. Official SHA-pinned v1.7.8 is a
supported in-place predecessor. Do not uninstall the previous version.

Verification: reproducible Build and exact main CI 40782440671 SUCCESS;
isolated Windows A/B actual upgrades/crash recovery 40782440727 SUCCESS;
native Z-order 40782440719 SUCCESS; hosted Explorer Start/Settings/Glass
40782440809 SUCCESS. All nine hosted jobs succeeded for source commit
479ee78a214c7ae58177016d59468e50e815f54b.

On the owner's Windows PC, the real 1.7.8 -> 1.7.9 per-user in-place upgrade,
configuration preservation and installed binary/hash checks passed. The app
was restarted and observed responding in the owner session. Dedicated
user-driven personal Start/Settings transition acceptance is not independently
claimed by these checks. Hosted Windows tests do not replace all hardware tests.

This installer is intentionally UNSIGNED under the owner's existing waiver,
not Authenticode-certified. Optional PawnIO is external and is not silently
installed. The physical AC-loss test was excluded by the owner. No independent
security clearance or guaranteed Windows notification audio is claimed.

Status: **staged candidate; not an assertion of public GitHub release**.
"""
write("RELEASE_NOTES_v1.7.9.md",notice)
now=dt.datetime.now(dt.timezone.utc).isoformat()
accept=dict(Schema=1,Revision="R294",Product="Taskbar Monitor Enhanced",Version="1.7.9",Tag="v1.7.9",SourceSHA=sha_main,
Status="SCOPED_UNSIGNED_RELEASE_CANDIDATE_ACCEPTANCE",AuthenticodeSigned=False,
OwnerPreviouslyApprovedUnsignedRelease=True,SinglePerUserInstaller=True,PriorOfficialVersion="1.7.8",
OwnerRealInPlaceUpgrade=True,OwnerSetupExitCode=0,OwnerSettingsHashesPreserved=True,OwnerSessionRestartPassed=True,
OwnerLiveTransitionStartSettingsIndependent=False,NativeHostedWindowsStartSettingsGlassPassed=True,
PhysicalPowerLossExcludedByOwner=True,IndependentSecurityLabAccepted=False,PublicReleaseNotYetPublishedAtConstruction=True,
CI=ci_ids,SetupSHA256=setup_sha,MainSHA256=main_sha,PrivateOwnerReceiptSHA256=owner_receipt_sha,PrivateOwnerEvidenceLocation="local only; never uploaded",RecordedUTC=now)
js("V1_7_9_OWNER_UNSIGNED_ACCEPTANCE.json",accept)
five_names=["RELEASE_NOTES_v1.7.9.md","SBOM_v1.7.9.spdx.json",srcname,"TaskbarMonitorEnhanced_Setup_1.7.9.exe","V1_7_9_OWNER_UNSIGNED_ACCEPTANCE.json"]
def info(n):return dict(Name=n,Bytes=(tmp/n).stat().st_size,SHA256=sha(tmp/n))
manifest=dict(Schema=2,Product="Taskbar Monitor Enhanced",Version="1.7.9",Tag="v1.7.9",
 SourceSHA=sha_main,SourceCommit=sha_main,Status="STABLE_UNSIGNED_CANDIDATE_NOT_PUBLISHED",
 AuthenticodeSigned=False,OwnerSigningWaiverRecorded=True,PhysicalPowerLossExcludedByOwner=True,
 ExternalSignedLabAccepted=False,ReleaseAssetCount=7,InstallerAssetCount=1,GeneratedUTC=now,
 CI=ci_ids,Assets=[info(n) for n in five_names],RuntimeOutputs=m["Outputs"],
 SBOM=dict(ProductVersion="1.7.9",SPDXVersion="SPDX-2.3"),
 OwnerUpgradeGate="PASS",OwnerPersonalStartSettingsDynamicGate="PENDING")
js("RELEASE_MANIFEST_v1.7.9.json",manifest)
sumsname="SHA256SUMS_v1.7.9.txt"
six=sorted(five_names+["RELEASE_MANIFEST_v1.7.9.json"])
write(sumsname,"".join(sha(tmp/n)+"  "+n+"\n" for n in six))
names=sorted(p.name for p in tmp.iterdir())
fail_if(len(names)!=7 or names.count("TaskbarMonitorEnhanced_Setup_1.7.9.exe")!=1,"NOT_EXACT_SEVEN")
actual={n:{"Bytes":(tmp/n).stat().st_size,"SHA256":sha(tmp/n)} for n in names}
synthetic=dict(tag_name="v1.7.9",draft=False,prerelease=False,immutable=True,target_commitish=sha_main,
               assets=[dict(name=n,size=actual[n]["Bytes"],state="uploaded",digest="sha256:"+actual[n]["SHA256"].lower()) for n in names])
spec=importlib.util.spec_from_file_location("g16",str(w/"build/verify_public_release_g16.py"))
g16=importlib.util.module_from_spec(spec)
spec.loader.exec_module(g16)
proof=g16.validate_public_content("v1.7.9",synthetic,manifest,(tmp/sumsname).read_text("utf-8"),actual,ci["Main"],sha_main)
fail_if(proof["Status"]!="PASS_PUBLICATION_CONTENT_ONLY","G16_SYNTHETIC_PREPUBLICATION")
tmp.rename(out)
print(json.dumps(dict(Status="PASS_OFFLINE_7_ASSETS_STAGED_NOT_PUBLISHED",SourceSHA=sha_main,
 SetupSHA256=setup_sha,SourceZipSha256=sha(out/srcname),G16ContentOnlySyntheticProof=proof,
 PublicReleaseCreated=False,OwnerDynamicStartSettingsPending=True,Outputs=actual),indent=2))
