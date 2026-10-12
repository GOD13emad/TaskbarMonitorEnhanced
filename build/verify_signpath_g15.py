#!/usr/bin/env python3
"""G15: authenticated, read-only SignPath request/origin/payload proof.
Authenticode trust and timestamps are validated independently in Test-Release-Gates.ps1.
Never makes a signing request or approves anything. Missing credentials => BLOCKED.
"""
from __future__ import annotations
import argparse, hashlib, io, json, os, pathlib, re, ssl, sys, urllib.error, urllib.parse, urllib.request, zipfile
REPO="https://github.com/GOD13emad/TaskbarMonitorEnhanced"
HOST="app.signpath.io"
MAX_META=1024*1024
MAX_ART=64*1024*1024
MAX_ENTRY=32*1024*1024
def require(ok,code):
    if not ok:raise ValueError("G15_REJECT_"+code)
def sha(v):return hashlib.sha256(v).hexdigest().lower()
def ensure_guid(s,label):
    require(isinstance(s,str) and re.fullmatch(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}",s) is not None,label)
    return s.lower()
def request_urls(org,req):
    prefix="https://"+HOST+"/Api/v1/"+ensure_guid(org,"ORGANIZATION_GUID")+"/SigningRequests/"+ensure_guid(req,"REQUEST_GUID")
    return prefix,prefix+"/SignedArtifact"
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl):
        raise ValueError("G15_REJECT_REDIRECT_DENIED")
def get_bytes(url,token,maxsize):
    parsed=urllib.parse.urlsplit(url)
    require(parsed.scheme=="https" and parsed.hostname==HOST and parsed.port is None and not parsed.query and not parsed.fragment,"TRUSTED_SIGNPATH_DOMAIN")
    opener=urllib.request.build_opener(NoRedirect(),urllib.request.HTTPSHandler(context=ssl.create_default_context()))
    req=urllib.request.Request(url,headers={"Authorization":"Bearer "+token,"Accept":"application/json" if url.endswith("SignedArtifact") is False else "application/octet-stream","User-Agent":"TaskbarMonitorEnhanced-ReadOnly-G15-R73"})
    with opener.open(req,timeout=18) as r:
        data=r.read(maxsize+1)
    require(len(data)<=maxsize,"RESPONSE_SIZE_LIMIT")
    return data
def verify_request_metadata(data,*,org,request,source,project,policy,repo=REPO):
    require(isinstance(data,dict),"REQUEST_NOT_OBJECT")
    if "signingRequestId" in data:
        require(str(data["signingRequestId"]).lower()==request.lower(),"REQUEST_ID_MISMATCH")
    require(data.get("status")=="Completed" and data.get("workflowStatus")=="Completed" and data.get("isFinalStatus") is True,"REQUEST_NOT_COMPLETED")
    require(data.get("projectSlug")==project and data.get("signingPolicySlug")==policy,"WRONG_PROJECT_OR_POLICY")
    origin=data.get("origin")
    require(isinstance(origin,dict),"NO_VERIFIED_ORIGIN")
    r=origin.get("repositoryData",{})
    normalized=str(r.get("url","")).rstrip("/").removesuffix(".git")
    require(normalized==repo and str(r.get("commitId","")).lower()==source.lower(),"SOURCE_OR_REPOSITORY_MISMATCH")
    require(str(r.get("sourceControlManagementType","")).lower()=="git","SCM_UNVERIFIED")
    build=origin.get("buildData",{})
    build_url=str(build.get("url",""))
    require(re.fullmatch(re.escape(repo)+r"/actions/runs/[0-9]+(?:/.*)?",build_url) is not None,"GITHUB_BUILD_ORIGIN")
    uri=data.get("signedArtifactLink","")
    _,expected=request_urls(org,request)
    require(uri==expected,"SIGNED_ARTIFACT_LINK")
    return {"SigningRequestId":request.lower(),"ProjectSlug":project,"Policy":policy,"SourceSHA":source.lower(),"TrustedBuildURL":build_url,"APIStatus":"Completed"}
def verify_signed_payload(payload,filename,expected_bytes):
    require(isinstance(payload,bytes) and len(payload)>0 and len(payload)<=MAX_ART,"SIGNED_PAYLOAD_SIZE")
    if payload[:4] in (b"PK\x03\x04",b"PK\x05\x06"):
        with zipfile.ZipFile(io.BytesIO(payload)) as z:
            entries=z.infolist()
            names=[x.filename for x in entries]
            require(len(names)==len(set(names)) and len(names)==len(set(x.casefold() for x in names)),"ZIP_DUPLICATE_NAMES")
            allowed=[]
            for x in entries:
                path=pathlib.PurePosixPath(x.filename)
                require(not x.filename.startswith("/") and ".." not in path.parts and "\\" not in x.filename,"ZIP_PATH")
                if not x.is_dir() and path.name==filename:allowed.append(x)
            require(len(allowed)==1,"SIGNED_ARTIFACT_FILENAME")
            entry=allowed[0]
            require(entry.file_size==len(expected_bytes) and entry.file_size<=MAX_ENTRY,"SIGNED_ARTIFACT_LENGTH")
            with z.open(entry) as stream:
                binary=stream.read(MAX_ENTRY+1)
            require(len(binary)==len(expected_bytes),"SIGNED_ENTRY_BYTECOUNT")
    else:
        binary=payload
    require(sha(binary)==sha(expected_bytes) and len(binary)==len(expected_bytes),"SIGNED_BINARY_MISMATCH")
    return {"Name":filename,"Bytes":len(expected_bytes),"SHA256":sha(expected_bytes)}
def evaluate(*,source,org,main_request,setup_request,project,policy,main_path,setup_path,token):
    require(re.fullmatch("[a-fA-F0-9]{40}",source or "") is not None,"SOURCE_SHA")
    require(re.fullmatch(r"[a-z0-9][a-z0-9-]{1,100}",project or "") is not None,"PROJECT_SLUG")
    require(re.fullmatch(r"[a-z0-9-]*release[a-z0-9-]*",policy or "") is not None,"MUST_BE_RELEASE_POLICY")
    require(bool(token) and len(token)<4096,"TOKEN_MISSING")
    main_request=ensure_guid(main_request,"MAIN_REQUEST")
    setup_request=ensure_guid(setup_request,"SETUP_REQUEST")
    files={"Main":pathlib.Path(main_path),"Setup":pathlib.Path(setup_path)}
    require(files["Main"].is_file() and files["Setup"].is_file() and files["Main"].resolve()!=files["Setup"].resolve(),"SIGNED_FILES_NOT_PRESENT")
    require(files["Main"].name=="TaskbarMonitorEnhanced.exe" and files["Setup"].name=="TaskbarMonitorEnhanced_Setup_1.7.0.exe","SIGNED_FILE_NAMES")
    pres={k:p.read_bytes() for k,p in files.items()}
    require(all(0<len(v)<MAX_ENTRY for v in pres.values()),"SIGNED_FILE_SIZE")
    proofs={}
    for key,request in (("Main",main_request),("Setup",setup_request)):
        metadata_url,artifact_url=request_urls(org,request)
        meta=json.loads(get_bytes(metadata_url,token,MAX_META).decode("utf-8-sig"))
        req_proof=verify_request_metadata(meta,org=org,request=request,source=source,project=project,policy=policy)
        artifact=get_bytes(artifact_url,token,MAX_ART)
        verified=verify_signed_payload(artifact,files[key].name,pres[key])
        proofs[key]={"Request":req_proof,"SignedBinary":verified}
    require(all(sha(files[k].read_bytes())==sha(v) for k,v in pres.items()),"SIGNED_FILE_CHANGED_DURING_CHECK")
    return {"Status":"PASS_SIGNPATH_PROVIDER_ORIGIN_AND_EXACT_SIGNED_BINARY","SourceSHA":source.lower(),
            "Provider":"SignPath","ReleasePolicy":policy,"Main":proofs["Main"],"Setup":proofs["Setup"],
            "HumanApproval":"EXTERNAL_SIGNPATH_POLICY_EVIDENCE_REQUIRES_INDEPENDENT_ACCEPTANCE",
            "WindowsAuthenticode":"SEPARATE_G15_POWERSHELL_VALIDATION"}
def main():
    p=argparse.ArgumentParser()
    for f in ("source","organization-id","main-request-id","setup-request-id","project-slug","policy-slug","main","setup"):
        p.add_argument("--"+f,required=True)
    a=p.parse_args()
    token=os.getenv("SIGNPATH_API_TOKEN","")
    try:
        proof=evaluate(source=a.source,org=a.organization_id,main_request=a.main_request_id,
                       setup_request=a.setup_request_id,project=a.project_slug,policy=a.policy_slug,
                       main_path=a.main,setup_path=a.setup,token=token)
        exit_code=0
    except Exception as e:
        proof={"Status":"BLOCKED_FAIL_CLOSED","ErrorClass":type(e).__name__,
               "Reason":str(e)[:160] if isinstance(e,ValueError) else "PROVIDER_API_OR_SIGNED_ARTIFACT_NOT_VERIFIED"}
        exit_code=45
    print(json.dumps(proof,sort_keys=True,ensure_ascii=False))
    return exit_code
if __name__=="__main__":sys.exit(main())
