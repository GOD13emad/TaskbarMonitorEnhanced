#!/usr/bin/env python3
"""R71 deterministic negative regressions against the exact live G16 validator."""
from __future__ import annotations
import copy, datetime, hashlib, json, pathlib, sys
from verify_public_release_g16 import validate_public_content
BASE=pathlib.Path(__file__).resolve().parent
TARGET=None

tag="v1.7.0"
source="a"*40
names=["TaskbarMonitorEnhanced_Setup_1.7.0.exe","TaskbarMonitorEnhanced_1.7.0_SOURCE.zip",
"RELEASE_NOTES_v1.7.0.md","SBOM_v1.7.0.spdx.json","V1_7_0_R71_ACCEPTANCE.json",
"RELEASE_MANIFEST_v1.7.0.json","SHA256SUMS_v1.7.0.txt"]
payloads={n:("R71:"+n).encode("utf-8") for n in names}
obs={n:{"Bytes":len(v),"SHA256":hashlib.sha256(v).hexdigest()} for n,v in payloads.items()}
assets=[{"name":n,"size":obs[n]["Bytes"],"digest":"sha256:"+obs[n]["SHA256"],"state":"uploaded"} for n in names]
release={"tag_name":tag,"draft":False,"prerelease":False,"immutable":True,
 "target_commitish":source,"assets":assets}
manifest={"Tag":tag,"Version":"1.7.0","SourceSHA":source,"CI":{"Main":876543},
"Assets":[{"Name":n,"SHA256":obs[n]["SHA256"],"Bytes":obs[n]["Bytes"]} for n in names[:5]],
"RuntimeOutputs":[{"Name":names[0],"SHA256":obs[names[0]]["SHA256"],"Bytes":obs[names[0]]["Bytes"]}]}
checksums="\n".join(obs[n]["SHA256"]+"  "+n for n in names if n!=names[-1])+"\n"
# checksum set should cover six assets including manifest, not the checksum file, so list without SHA256SUMS rather than assuming order.
checksums="\n".join(obs[n]["SHA256"]+"  "+n for n in names if n!="SHA256SUMS_v1.7.0.txt")+"\n"
ci={"id":876543,"head_sha":source,"head_branch":"main","status":"completed","conclusion":"success","event":"push"}
def validate(r,m,s,o,c,source=source,tag=tag):
    return validate_public_content(tag,r,m,s,o,c,source)
positive=validate(release,manifest,checksums,obs,ci)
assert positive["Status"]=="PASS_PUBLICATION_CONTENT_ONLY"
cases=[]
def add(name,modify):
    r,m,s,o,c=copy.deepcopy((release,manifest,checksums,obs,ci))
    args=[r,m,s,o,c]
    modify(args)
    cases.append((name,args))
add("R68_FORGED_MANIFEST_BYTES",lambda a:a[1]["Assets"][0].__setitem__("Bytes",a[1]["Assets"][0]["Bytes"]+1))
add("R68_FORGED_MANIFEST_HASH",lambda a:a[1]["Assets"][1].__setitem__("SHA256","f"*64))
add("FORGED_MANIFEST_AND_SUMS",lambda a:(a[1]["Assets"][0].__setitem__("SHA256","a"*64),a.__setitem__(2,a[2].replace(obs[names[0]]["SHA256"],"a"*64))))
add("MANIFEST_FOUR_ASSETS",lambda a:a[1].__setitem__("Assets",a[1]["Assets"][:4]))
add("MANIFEST_DUPLICATED_ASSET",lambda a:a[1]["Assets"][4].__setitem__("Name",names[0]))
add("MANIFEST_EXTRA_ASSET",lambda a:a[1]["Assets"].append({"Name":"extra","Bytes":1,"SHA256":"b"*64}))
add("MANIFEST_WRONG_SOURCE",lambda a:a[1].__setitem__("SourceSHA","b"*40))
add("MANIFEST_WRONG_TAG",lambda a:a[1].__setitem__("Tag","v0.0.0"))
add("DOWNLOAD_MISSING",lambda a:a[3].pop(names[0]))
add("DOWNLOAD_WRONG_SIZE",lambda a:a[3][names[0]].__setitem__("Bytes",99))
add("DOWNLOAD_WRONG_HASH",lambda a:a[3][names[0]].__setitem__("SHA256","0"*64))
add("GITHUB_DIGEST_FORGED",lambda a:a[0]["assets"][0].__setitem__("digest","sha256:"+"0"*64))
add("GITHUB_SIZE_FORGED",lambda a:a[0]["assets"][1].__setitem__("size",3))
add("GITHUB_RELEASE_MUTABLE",lambda a:a[0].__setitem__("immutable",False))
add("GITHUB_RELEASE_DRAFT",lambda a:a[0].__setitem__("draft",True))
add("GITHUB_RELEASE_WRONG_TARGET",lambda a:a[0].__setitem__("target_commitish","0"*40))
add("GITHUB_ASSET_STATE_NOT_UPLOADED",lambda a:a[0]["assets"][2].__setitem__("state","pending"))
add("GITHUB_SEVEN_ASSETS_MISSING",lambda a:a[0]["assets"].pop())
add("GITHUB_DUPLICATE_ASSET_NAME",lambda a:a[0]["assets"][6].__setitem__("name",names[0]))
add("CHECKSUM_HASH_WRONG",lambda a:a.__setitem__(2,a[2].replace(obs[names[0]]["SHA256"],"0"*64)))
add("CHECKSUM_COVERAGE_MISSING",lambda a:a.__setitem__(2,"\n".join(a[2].splitlines()[:-1])+"\n"))
add("CHECKSUM_DUPLICATE_NAME",lambda a:a.__setitem__(2,a[2].replace(names[1],names[0])))
add("CHECKSUM_BAD_DELIMITER",lambda a:a.__setitem__(2,a[2].replace("  "," ",1)))
add("CI_ID_MISMATCH",lambda a:a[4].__setitem__("id",1))
add("CI_SHA_MISMATCH",lambda a:a[4].__setitem__("head_sha","0"*40))
add("CI_BRANCH_WRONG",lambda a:a[4].__setitem__("head_branch","feature"))
add("CI_FAILURE",lambda a:a[4].__setitem__("conclusion","failure"))
add("CI_NOT_COMPLETE",lambda a:a[4].__setitem__("status","in_progress"))
add("CI_INVALID_EVENT",lambda a:a[4].__setitem__("event","pull_request"))
add("RUNTIME_SETUP_MISMATCH",lambda a:a[1]["RuntimeOutputs"][0].__setitem__("SHA256","0"*64))
add("UNDECLARED_CHECKSUM_NAME",lambda a:a.__setitem__(2,a[2].replace(names[0],"INVALID.exe")))
add("INVALID_MANIFEST_CI_ID",lambda a:a[1]["CI"].__setitem__("Main","876543"))
blocked=[]
false_accepted=[]
for label,args in cases:
    try:validate(*args)
    except (ValueError,KeyError,TypeError,AttributeError) as e:blocked.append({"Case":label,"Rejection":str(e)[:150]})
    else:false_accepted.append(label)
result={"Schema":1,"Revision":"R72","UTC":datetime.datetime.now(datetime.timezone.utc).isoformat(),
"PositiveCases":1,"NegativeCases":len(cases),"NegativeRejected":len(blocked),"FalseAccepted":false_accepted,
"LiveProductionAcceptance":"NOT_INFERRED_FROM_SYNTHETIC",
"Status":"PASS" if len(blocked)==len(cases) and not false_accepted else "FAIL",
"Cases":blocked}
if TARGET is not None:
    TARGET.write_text(json.dumps(result,ensure_ascii=False,indent=2,sort_keys=True)+"\n",encoding="utf-8")
print(json.dumps({k:v for k,v in result.items() if k!="Cases"},sort_keys=True))
if result["Status"]!="PASS":sys.exit(45)
