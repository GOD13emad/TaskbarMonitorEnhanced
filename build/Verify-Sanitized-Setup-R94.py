#!/usr/bin/env python3
"""R94 release-candidate static safety attestation. Actual Windows migration CI is separate.
Accepts exact immutable binary and exact sanitized Setup source, checks forbidden test-only
crash/fault/diagnostic strings against BOTH source and assembly bytes with 12 hostile negatives.
No executable code launched, no install/uninstall, no deletion or mutation of user data.
"""
from __future__ import annotations
import argparse,datetime,hashlib,json,pathlib,re,sys
EXACT_SETUP_SHA="63B811A5343C4FD066F39927F428C1F49CF2581A9348FF281B3260E0C860A5ED"
EXACT_SOURCE_SHA="38C89A12D85DAC49BB640A2C6B2F78E4C405879D83330725F49CF30C486B8F14"
FORBIDDEN=("FailFast","TBME_TEST_","WriteHostedUpgradeFailure",
           "R92_TEST_ONLY_FAULT_INJECTION","R93_EPHEMERAL_PROCESS_DEATH","R92_CI_ONLY_UPGRADE_FAILURE")
REQUIRED=("UpgradeExisting","RecoverUpgradeStageIfAny","CheckSingleCanonicalRoot",
          "VerifyLegacyFiles","RestoreInterruptedUpgrade","CleanOwnedStage",
          'if(File.Exists(AppExe) || ExistingRegistered())return UpgradeExisting();')
def sha(b):return hashlib.sha256(b).hexdigest().upper()
def reject(t):raise RuntimeError("R94_SANITIZED_SOURCE_BINARY_REJECT_"+t)
def matches_any(blob,term):
    # CLR metadata #US literals are usually UTF-16LE, method names ASCII/UTF-8.
    # Check both byte alignments of UTF16LE by searching the raw contiguous bytes.
    return term.encode("ascii") in blob or term.encode("utf-16le") in blob
def forbidden_matches(blob):return [v for v in FORBIDDEN if matches_any(blob,v)]
def inspect(source,binary):
    problems=[]
    if forbidden_matches(source):problems.append("SOURCE_CONTAINS_TEST_HOOKS_"+",".join(forbidden_matches(source)))
    if forbidden_matches(binary):problems.append("BINARY_CONTAINS_TEST_HOOKS_"+",".join(forbidden_matches(binary)))
    try:source_text=source.decode("utf-8-sig")
    except UnicodeDecodeError:problems.append("SOURCE_NOT_UTF8");source_text=""
    for contract in REQUIRED:
        if contract not in source_text:problems.append("UPDATER_CONTRACT_MISSING_"+contract[:22])
    return problems
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",type=pathlib.Path,required=True)
    ap.add_argument("--setup",type=pathlib.Path,required=True)
    ap.add_argument("--output",type=pathlib.Path,required=True)
    args=ap.parse_args()
    if args.output.exists():reject("NO_UNSAFE_RERUN_OF_ATTESTATION")
    if not args.source.is_file() or not args.setup.is_file():reject("PINNED_INPUT_ABSENT")
    source=args.source.read_bytes()
    setup=args.setup.read_bytes()
    if sha(source)!=EXACT_SOURCE_SHA:reject("EXACT_SOURCE_SHA_CHANGED")
    if sha(setup)!=EXACT_SETUP_SHA:reject("EXACT_BINARY_SHA_CHANGED")
    faults=inspect(source,setup)
    if faults:reject("ACTUAL_"+",".join(faults))
    adversarial=[]
    for token in FORBIDDEN:
        altered_source=source+b"\n// "+token.encode("ascii")+b"\n"
        altered_assembly=setup+token.encode("utf-16le")
        if not inspect(altered_source,setup):reject("SOURCE_NEGATIVE_TEST_FALSELY_PASSED_"+token)
        if not inspect(source,altered_assembly):reject("BINARY_NEGATIVE_TEST_FALSELY_PASSED_"+token)
        adversarial.extend(["SOURCE_"+token,"BINARY_"+token])
    control={
      "Schema":1,"Revision":"R95","UTC":datetime.datetime.now(datetime.timezone.utc).isoformat(),
      "Status":"PASS_EXACT_RELEASE_SANITIZED_BINARY_AND_SOURCE_NO_TEST_HOOKS",
      "SourceSHA256":sha(source),"SetupSHA256":sha(setup),"SourcePath":str(args.source),
      "SetupPath":str(args.setup),"UnsignedExpected":True,
      "ForbiddenTestHooksAbsent":list(FORBIDDEN),
      "HostileNegativeRegressions":adversarial,"NegativeCount":len(adversarial),
      "UpdaterCoreContractsPreserved":list(REQUIRED),
      "ValidationBoundary":"STATIC_BINARY_AND_SOURCE_ONLY_REAL_INPLACE_TESTS_SEPARATE",
      "FormalStableAccepted":False,"ReadyForPublicReleaseApproval":False}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(control,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    print("R94_SANITIZED_SETUP_STATIC_PASS exact_sha="+EXACT_SETUP_SHA+
          " forbidden_tests_absent="+str(len(FORBIDDEN))+" negative_regressions="+str(len(adversarial))+
          " attestation_sha256="+sha(args.output.read_bytes()))
if __name__=="__main__":main()
