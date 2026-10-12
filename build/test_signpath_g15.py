#!/usr/bin/env python3
"""Synthetic-contract NEGATIVE tests only; cannot imply SignPath approval or signed real files."""
from __future__ import annotations
import copy, io, json, zipfile, sys
from verify_signpath_g15 import verify_request_metadata, verify_signed_payload
ORG="12345678-1234-1234-1234-123456789abc"
RID="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
SHA="a"*40
PROJECT="taskbarmonitorenhanced"
POLICY="release-signing"
META={"signingRequestId":RID,"status":"Completed","workflowStatus":"Completed","isFinalStatus":True,
"projectSlug":PROJECT,"signingPolicySlug":POLICY,
"origin":{"repositoryData":{"url":"https://github.com/GOD13emad/TaskbarMonitorEnhanced","commitId":SHA,"sourceControlManagementType":"git","branchName":"main"},
"buildData":{"url":"https://github.com/GOD13emad/TaskbarMonitorEnhanced/actions/runs/123456"}} ,
"signedArtifactLink":f"https://app.signpath.io/Api/v1/{ORG}/SigningRequests/{RID}/SignedArtifact"}
kw={"org":ORG,"request":RID,"source":SHA,"project":PROJECT,"policy":POLICY}
def check(meta):return verify_request_metadata(meta,**kw)
assert check(copy.deepcopy(META))["APIStatus"]=="Completed"
neg=[]
def case(label,func):
    m=copy.deepcopy(META);func(m)
    try:check(m)
    except (ValueError,KeyError,TypeError,AttributeError) as e:neg.append((label,str(e)[:160]))
    else:raise SystemExit("G15_FALSE_ACCEPTED_"+label)
case("NOT_COMPLETED",lambda m:m.__setitem__("status","WaitingForApproval"))
case("NOT_WORKFLOW_COMPLETED",lambda m:m.__setitem__("workflowStatus","Processing"))
case("NOT_FINAL",lambda m:m.__setitem__("isFinalStatus",False))
case("WRONG_PROJECT",lambda m:m.__setitem__("projectSlug","another-project"))
case("TEST_POLICY",lambda m:m.__setitem__("signingPolicySlug","test-signing"))
case("REQUEST_ID_SWAP",lambda m:m.__setitem__("signingRequestId","bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"))
case("NO_ORIGIN",lambda m:m.pop("origin"))
case("REPO_SPOOF",lambda m:m["origin"]["repositoryData"].__setitem__("url","https://github.com/attacker/TaskbarMonitorEnhanced"))
case("SHA_SPOOF",lambda m:m["origin"]["repositoryData"].__setitem__("commitId","0"*40))
case("SCM_SPOOF",lambda m:m["origin"]["repositoryData"].__setitem__("sourceControlManagementType","mercurial"))
case("BUILD_JOB_WRONG_REPO",lambda m:m["origin"]["buildData"].__setitem__("url","https://github.com/attacker/project/actions/runs/123"))
case("BUILD_JOB_NOT_GITHUB_ACTIONS",lambda m:m["origin"]["buildData"].__setitem__("url","https://evil.example/build"))
case("SIGNED_ARTIFACT_LINK_EXTERNAL",lambda m:m.__setitem__("signedArtifactLink","https://evil.example/UnsignedArtifact"))
case("SIGNED_ARTIFACT_LINK_OTHER_ID",lambda m:m.__setitem__("signedArtifactLink",m["signedArtifactLink"].replace(RID,"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")))
payload=b"R73 synthetic executable content only"
valid=verify_signed_payload(payload,"TaskbarMonitorEnhanced.exe",payload)
assert valid["Bytes"]==len(payload)
def makezip(records):
    buff=io.BytesIO()
    with zipfile.ZipFile(buff,"w",compression=zipfile.ZIP_DEFLATED) as z:
        for k,v in records:z.writestr(k,v)
    return buff.getvalue()
z=makezip([("build/App/TaskbarMonitorEnhanced.exe",payload)])
assert verify_signed_payload(z,"TaskbarMonitorEnhanced.exe",payload)["SHA256"]==valid["SHA256"]
def artifact_case(label,z,expected=payload):
    try:verify_signed_payload(z,"TaskbarMonitorEnhanced.exe",expected)
    except (ValueError,KeyError,TypeError,zipfile.BadZipFile) as e:neg.append((label,str(e)[:160]))
    else:raise SystemExit("G15_FALSE_ACCEPTED_"+label)
artifact_case("SIGNED_HASH_MISMATCH",b"fake executable",payload)
artifact_case("SIGNED_ZIP_MISSING_EXE",makezip([("other.exe",payload)]))
artifact_case("SIGNED_ZIP_DUPLICATE_EXE",makezip([("one/TaskbarMonitorEnhanced.exe",payload),("two/TaskbarMonitorEnhanced.exe",payload)]))
artifact_case("SIGNED_ZIP_PATH_TRAVERSAL",makezip([("../TaskbarMonitorEnhanced.exe",payload)]))
artifact_case("SIGNED_ZIP_WRONG_BYTES",makezip([("TaskbarMonitorEnhanced.exe",b"wrong")]))
artifact_case("SIGNED_ZIP_EMPTY",makezip([]))
artifact_case("SIGNED_ZIP_DUPLICATE_NAMES",makezip([("TaskbarMonitorEnhanced.exe",payload),("TaskbarMonitorEnhanced.exe",payload)]))
result={"Revision":"R73","SyntheticPositiveCases":2,"NegativeTests":len(neg),"Rejected":len(neg),
"FalseAccepted":[],"Status":"PASS","ProductionSignPathApproval":"UNPROVEN_REQUIRES_REAL_SIGNED_PROVIDER_API_AND_HUMAN",
"Cases":[{"Name":x,"RejectedBecause":y} for x,y in neg]}
print(json.dumps(result,sort_keys=True,ensure_ascii=False))
