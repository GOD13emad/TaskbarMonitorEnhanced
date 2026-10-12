#!/usr/bin/env python3
"""Read-only GitHub G16 publication proof: 7 real asset downloads, manifest, sums, main CI.
A historical release PASS is only a schema/regression proof, never current v1.7 Stable acceptance.
"""
from __future__ import annotations
import argparse, datetime, hashlib, json, pathlib, re, sys, urllib.error, urllib.request
REPO="GOD13emad/TaskbarMonitorEnhanced"
API="https://api.github.com/repos/"+REPO
URL="https://github.com/"+REPO+"/releases/download/"
ROOT=pathlib.Path(__file__).resolve().parent.parent
EVIDENCE=ROOT/".local"
MAX_BYTES=50*1024*1024
def sha(b:bytes)->str:return hashlib.sha256(b).hexdigest().lower()
def require(p:bool,code:str):
    if not p:raise ValueError("G16_REJECT_"+code)
def fetch(url:str,limit:int=MAX_BYTES)->bytes:
    request=urllib.request.Request(url,headers={"User-Agent":"TaskbarMonitorEnhanced-G16-independent-auditor-R71",
        "Accept":"application/vnd.github+json" if url.startswith(API) else "application/octet-stream"})
    with urllib.request.urlopen(request,timeout=22) as r:
        payload=r.read(limit+1)
    require(len(payload)<=limit,"DOWNLOAD_TOO_LARGE")
    return payload
def get_json(url:str):return json.loads(fetch(url,1024*1024).decode("utf-8-sig"))
def names_for(tag:str,found:list[str]):
    require(re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+",tag) is not None,"VERSION")
    version=tag[1:]
    v_us=version.replace(".","_")
    accept=[n for n in found if re.fullmatch(r"V"+v_us+r"_[A-Za-z0-9_]+_ACCEPTANCE\.json",n)]
    require(len(accept)==1,"ACCEPTANCE_ASSET_NAME")
    five={
        "TaskbarMonitorEnhanced_Setup_"+version+".exe",
        "TaskbarMonitorEnhanced_"+version+"_SOURCE.zip",
        "RELEASE_NOTES_"+tag+".md",
        "SBOM_"+tag+".spdx.json",
        accept[0]
    }
    manifest="RELEASE_MANIFEST_"+tag+".json"
    sums="SHA256SUMS_"+tag+".txt"
    require(len(five)==5 and len(set(found))==7 and set(found)==five|{manifest,sums},"EXACT_SEVEN_NAMES")
    return five,manifest,sums
def validate_public_content(tag:str,release:dict,manifest:dict,checksums:str,actual:dict,
                            main_ci:dict,expected_source:str)->dict:
    """Same validator used by live network and synthetic negative regression; no bypass option."""
    require(re.fullmatch(r"[a-f0-9]{40}",expected_source) is not None,"SOURCE_SHA_INPUT")
    require(release.get("tag_name")==tag and release.get("draft") is False
        and release.get("prerelease") is False and release.get("immutable") is True,"IMMUTABLE_RELEASE")
    require(release.get("target_commitish")==expected_source,"RELEASE_TARGET_SOURCE")
    metadata=release.get("assets")
    require(isinstance(metadata,list) and len(metadata)==7,"SEVEN_ASSET_METADATA")
    names=[a.get("name") for a in metadata]
    five,mname,sname=names_for(tag,names)
    byname={a["name"]:a for a in metadata}
    require(set(actual)==set(names),"DOWNLOADED_SEVEN_COMPLETE")
    for name in names:
        asset=byname[name]
        obs=actual[name]
        require(asset.get("state")=="uploaded","ASSET_STATE_"+name)
        require(isinstance(asset.get("size"),int) and asset["size"]>0,"ASSET_SIZE_"+name)
        require(obs["Bytes"]==asset["size"],"ASSET_DOWNLOADED_BYTES_"+name)
        digest=asset.get("digest","")
        require(isinstance(digest,str) and digest.lower()=="sha256:"+obs["SHA256"].lower(),"ASSET_GITHUB_DIGEST_"+name)
    require(manifest.get("Tag")==tag and manifest.get("Version")==tag[1:],"MANIFEST_VERSION")
    require(manifest.get("SourceSHA")==expected_source,"MANIFEST_SOURCE")
    declared=manifest.get("Assets")
    require(isinstance(declared,list) and len(declared)==5,"MANIFEST_FIVE_ENTRIES")
    declared_names=[x.get("Name") for x in declared]
    require(len(set(declared_names))==5 and set(declared_names)==five,"MANIFEST_ASSETS_COVERAGE")
    for x in declared:
        name=x["Name"]
        require(isinstance(x.get("Bytes"),int) and x["Bytes"]==actual[name]["Bytes"],"MANIFEST_ASSET_BYTES_"+name)
        require(re.fullmatch(r"[0-9a-fA-F]{64}",str(x.get("SHA256",""))) is not None
            and x["SHA256"].lower()==actual[name]["SHA256"].lower(),"MANIFEST_ASSET_SHA_"+name)
    rows=[x for x in checksums.splitlines() if x.strip()]
    require(len(rows)==6,"SIX_CHECKSUM_LINES")
    checked={}
    for row in rows:
        m=re.fullmatch(r"([0-9a-fA-F]{64})  ([A-Za-z0-9_.-]+)",row)
        require(m is not None,"CHECKSUMS_SYNTAX")
        h,name=m.groups()
        require(name not in checked,"DUPLICATE_CHECKSUM_NAME")
        checked[name]=h.lower()
    require(set(checked)==set(names)-{sname},"SIX_CHECKSUM_NAMES")
    for name,h in checked.items():require(h==actual[name]["SHA256"].lower(),"CHECKSUM_ACTUAL_"+name)
    # The manifest may be internally consistent but refer to a different Setup than the downloaded artifact.
    runtime=manifest.get("RuntimeOutputs",[])
    for r in runtime:
        if r.get("Name") in actual:
            name=r["Name"]
            require(str(r.get("SHA256","")).lower()==actual[name]["SHA256"].lower()
                    and r.get("Bytes")==actual[name]["Bytes"],"RUNTIME_OUTPUT_MISMATCH_"+name)
    require(isinstance(manifest.get("CI"),dict) and isinstance(manifest["CI"].get("Main"),int),"CI_ID")
    require(main_ci.get("id")==manifest["CI"]["Main"],"CI_RUN_ID")
    require(main_ci.get("head_sha")==expected_source
            and main_ci.get("head_branch")=="main"
            and main_ci.get("status")=="completed"
            and main_ci.get("conclusion")=="success"
            and main_ci.get("event") in ("push","workflow_dispatch"),"CI_EXACT_MAIN")
    return {"AssetCount":7,"ManifestPayloadEntries":5,"ChecksumEntries":6,"SourceSHA":expected_source,
            "GitHubMainCI":main_ci["id"],"AssetIntegrity":"PASS","Status":"PASS_PUBLICATION_CONTENT_ONLY"}
def audit(tag,expected_source):
    release=get_json(API+"/releases/tags/"+tag)
    md=release.get("assets",[])
    require(len(md)==7,"RELEASE_COUNT")
    names=[x.get("name") for x in md]
    _,manifestname,sumsname=names_for(tag,names)
    prefix=URL+tag+"/"
    actual={}
    raw={}
    for asset in md:
        name=asset["name"]
        url=asset.get("browser_download_url","")
        require(url==prefix+name,"RELEASE_URL_"+name)
        body=fetch(url)
        raw[name]=body
        actual[name]={"Bytes":len(body),"SHA256":sha(body)}
    manifest=json.loads(raw[manifestname].decode("utf-8-sig"))
    sums=raw[sumsname].decode("utf-8-sig")
    ci_id=manifest.get("CI",{}).get("Main")
    require(isinstance(ci_id,int),"MANIFEST_CI_MAIN_ID")
    main_ci=get_json(API+"/actions/runs/"+str(ci_id))
    proof=validate_public_content(tag,release,manifest,sums,actual,main_ci,expected_source)
    proof.update({"Tag":tag,"DownloadEvidence":actual,"ReleaseId":release.get("id"),
                  "PublishedAt":release.get("published_at"),"Immutable":True})
    return proof
def main():
    a=argparse.ArgumentParser()
    a.add_argument("--tag",required=True)
    a.add_argument("--source",required=True)
    a.add_argument("--output",default="")
    args=a.parse_args()
    target=pathlib.Path(args.output).resolve() if args.output else None
    if target is not None:
        require(target.parent==EVIDENCE.resolve(),"OUTPUT_OUTSIDE_PROJECT_LOCAL")
        require(not target.exists(),"NONOVERWRITE")
    when=datetime.datetime.now(datetime.timezone.utc).isoformat()
    try:
        result=audit(args.tag,args.source)
        result.update({"Revision":"R72","ObservedUTC":when,
            "CurrentV17G16":"UNPROVEN" if args.tag!="v1.7.0" else "PUBLICATION_ONLY_G13_G14_G15_SEPARATE",
            "NoProductMutation":True,"NoPublicationMutation":True})
        code=0
    except Exception as e:
        result={"Revision":"R72","ObservedUTC":when,"Tag":args.tag,
                "Status":"BLOCKED_FAIL_CLOSED","FailureClass":type(e).__name__,
                "Failure":str(e)[:350],"CurrentV17G16":"BLOCKED",
                "NoProductMutation":True,"NoPublicationMutation":True}
        code=45
    if target is not None:
        target.write_text(json.dumps(result,indent=2,ensure_ascii=False,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps(result,ensure_ascii=False,sort_keys=True))
    return code
if __name__=="__main__":sys.exit(main())
