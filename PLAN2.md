# PLAN2 — First Clean State and First Release Plan

> This plan is based on a full read of all repository Markdown docs:
> `README.md`, `FEATURES.md`, `OPTIMIZATION.md`, `PLAN1.md`, `2026-02-27-TODO.md`, `AGENTS.md`.
>
> Goal: get the project to a clean, internally consistent, first-release-ready state.
> Constraint for this step: **no code changes yet**. This file is the plan only.

---

## 1. Executive Summary

The project already looks technically strong.

What is clearly present already:
- DKMS packaging for the main `rknpu` module
- Separate `dma32-heap` DKMS module for the 8 GB constraint
- Working installer (`install.sh`)
- Real hardware/benchmark notes
- Good deep technical documentation
- Explicit known limitations and future work
- Small manual test utilities under `tests/`

What is **not** clean enough yet for a first public release:
- The documentation is internally inconsistent in several important places
- Release metadata is incomplete
- Validation is described, but not yet packaged as a reproducible release checklist
- The repo still contains historical/transition-state information that is useful for development but noisy for a first release

Conclusion:
- **The driver itself appears close to releasable**
- **The repository is not yet documentation-clean or release-clean**
- The first release should focus on **consistency, validation, packaging hygiene, and user-facing clarity** before more optimization work

---

## 2. Main Findings

## 2.1 What is missing

### A. Root release artifacts are missing
- No root `LICENSE` file was found
- No `CHANGELOG` / release notes file was found
- No dedicated release checklist doc exists as a stable user-facing document
- No explicit uninstall / rollback document exists

### B. Documentation architecture is not clean yet
Current docs mix three kinds of content:
- user-facing install/verify documentation
- developer/internal analysis
- historical investigation notes

For a first release this should be separated more clearly.

### C. Validation is not yet release-grade
There are useful manual test artifacts:
- `tests/test_direct_alloc.c`
- `tests/bench_yolov5.py`
- `tests/thermal_info.sh`

But what is missing is a single reproducible validation flow that answers:
- what must pass before release
- on which board/kernel/userspace combination it was tested
- what exact outputs are expected
- which findings are mandatory vs optional

### D. Versioning is inconsistent
Observed versions:
- docs say `RKNPU v0.9.8`
- DKMS package version is `1.0`
- installer uses DKMS version `1.0`

Before first release there must be one explicit versioning decision.

---

## 2.2 What is contradictory right now

### A. DT / boot configuration story is contradictory
There is a major inconsistency between docs and installer behavior.

Evidence:
- `README.md` says a custom DTB is included and installed
- `install.sh` explicitly sets:
  - `fdtfile=rockchip/rk3568-odroid-m1-npu.dtb`
  - `user_overlays=rknpu`
- `FEATURES.md` still mentions the same custom DTB override
- `2026-02-27-TODO.md` says the current setup is already:
  - stock DTB
  - single overlay only
  - **no `fdtfile` override needed**
  - custom DTB removed

This must be resolved before release because it affects installation safety and correctness.

### B. IOMMU status is contradictory
Evidence:
- `README.md` says `IOMMU (translated mode)` is working
- `FEATURES.md` says `IOMMU (translated mode)` is working
- `AGENTS.md` previously described the IOMMU state incorrectly

This was a release blocker at the documentation level because it changed how users understood memory constraints and risk. The final v1 documentation should state the verified runtime result directly: IOMMU translated mode is active on the target board.

### C. README status vs current implementation is contradictory
`PLAN1.md` already notes that the README is outdated.

That confirms the repo itself already knows the user-facing doc is behind the actual implementation.

---

## 2.3 What can be improved

### A. Reduce historical noise in top-level docs
Useful, but currently noisy for release:
- `2026-02-27-TODO.md`
- `PLAN1.md`
- `OPTIMIZATION.md`

These are valuable development documents, but a first release should make it obvious which docs are:
- for users
- for contributors
- historical notes only

### B. Provide a narrow, safe install story
A first release should make these points unambiguous:
- supported board(s)
- supported kernel range
- required userspace packages
- whether stock Armbian DTB is enough
- whether the installer edits boot config
- how to revert changes
- what exactly is expected after reboot

### C. Formalize support matrix
Minimum matrix to state explicitly:
- board model / RAM variant
- Armbian version family
- kernel range actually validated
- RKNN SDK version tested
- known unsupported combinations

### D. Make test utilities releasable
Current state is development-friendly, not release-friendly.

Examples:
- `tests/bench_yolov5.py` contains a hardcoded local absolute model path
- no single test runner / checklist ties the test artifacts together
- expected pass criteria are not centrally documented

### E. Distinguish blockers from future work
A clean 1.0 should separate:
- release blockers
- post-1.0 cleanup
- post-1.0 performance work
- external blockers outside this repo

The repo already contains this information, but it is spread across multiple docs.

---

## 3. Release Readiness Assessment

## 3.1 Ready enough already
- Driver feature set appears broadly complete
- Installation approach exists
- DKMS packaging exists
- Benchmarks and hardware notes exist
- Known limitations are documented
- There is already a strong technical narrative for why this repo exists

## 3.2 Not ready enough yet
- User-facing docs are not authoritative yet
- Installer behavior and docs disagree
- Version numbers disagree
- No root license file
- No changelog / release notes
- No clean validation document for fresh-system testing

---

## 4. Plan of Work

## Phase 0 — Decide the authoritative truth

### Goal
Choose the exact current truth for installation and runtime architecture.

### Must decide
- Is the release based on **custom DTB + overlay**, or **stock DTB + overlay only**?
- Is IOMMU translated mode actually enabled in the shipping configuration, or not?
- Is the release version `0.9.8`, `1.0`, or `1.0.0`?

### Output
A short authoritative decision record that all docs and scripts will follow.

### Priority
**Blocker**

---

## Phase 1 — Clean the repository for a first public release

### Goal
Turn the repo from “working engineering repo” into “releasable project repo”.

### Tasks
1. Add root `LICENSE`
2. Add `CHANGELOG.md` or `RELEASE_NOTES.md`
3. Add a release-oriented validation doc
4. Add uninstall / rollback documentation
5. Reorganize doc roles:
   - `README.md` = install + verify + support matrix + limitations
   - `FEATURES.md` = technical capability matrix
   - `AGENTS.md` = contributor/agent context only
   - `PLAN1.md`, `2026-02-27-TODO.md`, `OPTIMIZATION.md` = clearly marked as internal or archival

### Priority
**High**

---

## Phase 2 — Fix all documentation contradictions

### Goal
Make the repo internally consistent.

### Required fixes
1. Align DT/overlay/install story across:
   - `README.md`
   - `FEATURES.md`
   - `install.sh`
   - any release notes
2. Align IOMMU wording everywhere
3. Align versioning everywhere
4. Align verification commands and expected outputs
5. Remove or label stale claims clearly

### Definition of done
A new reader should be able to answer these questions from the repo without ambiguity:
- What exactly gets installed?
- What boot configuration changes happen?
- Does the system need a custom DTB?
- Is IOMMU on or off in the release configuration?
- What version am I installing?

### Priority
**Blocker**

---

## Phase 3 — Make validation reproducible

### Goal
Have a clean “fresh system” release validation process.

### Tasks
1. Define one validation environment:
   - board
   - RAM size
   - Armbian image
   - kernel version
   - RKNN SDK/runtime version
2. Create a step-by-step validation checklist:
   - install dependencies
   - run installer
   - reboot
   - confirm module load
   - confirm device nodes
   - confirm dma heap symlink
   - confirm devfreq entries
   - confirm thermal bindings
   - run direct allocation/import test
   - run at least one benchmark smoke test
3. Record expected outputs / success criteria
4. Record known acceptable deviations

### Nice follow-up
Wrap the current manual tests into a documented validation workflow.

### Priority
**High**

---

## Phase 4 — Do the minimal code/doc hygiene needed for 1.0

### Goal
Ship a first clean release without scope creep.

### In scope before first release
- Documentation corrections
- Installer correction if docs prove it is outdated
- Version normalization
- Release artifacts
- Validation pass on a fresh system

### Explicitly not required before first release
- Major performance redesign
- IOMMU/kernel-side research outside this repo
- zero-copy pipeline work
- deep allocator refactors
- aggressive cleanup that risks destabilizing a now-working driver

### Priority
**High**

---

## Phase 5 — Post-1.0 cleanup and improvement track

These are worthwhile, but should not block the first release unless they expose correctness issues.

### Cleanup candidates
- remove old kernel compatibility guards
- remove `FPGA_PLATFORM` guards
- remove `CONFIG_NO_GKI` guards
- remove stale/dead code paths

### Medium-risk performance work
- `kmem_cache` for `rknpu_job`
- `kmem_cache` for GEM tracking structs
- hash table for GEM address lookup
- hash/xarray for mem sync lookup

### Future / external work
- real load tracking via hardware counters
- buffer pool optimization
- skip redundant DMA-BUF attach/map path
- kernel-side IOMMU fix for full translated mode

### Priority
**After first release**

---

## 5. Proposed Release Order

1. Resolve architecture truth and version truth
2. Fix installer/doc contradictions
3. Add missing release files (`LICENSE`, changelog, validation doc)
4. Clean README into authoritative quickstart
5. Run fresh-system validation
6. Cut first release tag
7. Move remaining code cleanup/perf items to post-release backlog

---

## 6. Concrete Deliverables for the Next Editing Session

## Mandatory
- Updated `README.md`
- Updated `FEATURES.md`
- Possibly updated `install.sh` if it conflicts with the decided install model
- New root `LICENSE`
- New `CHANGELOG.md` or `RELEASE_NOTES.md`
- New release validation document
- Optional `UNINSTALL.md` or rollback section in `README.md`

## Optional but recommended
- Mark `PLAN1.md`, `OPTIMIZATION.md`, and `2026-02-27-TODO.md` as internal/history docs
- Add a short support matrix section to `README.md`
- Normalize version strings in all docs and package files

---

## 7. Recommended First Release Positioning

Suggested framing:
- first public release for **ODROID-M1 only**
- use **Armbian May 2026 release stream or newer**
- repo kernel target **6.18+**
- tested with **RKNN SDK 2.4.0**
- clearly document the final runtime configuration without transitional workaround history
- clearly document all non-goals and hard hardware/firmware limits

This keeps the release narrow, believable, and easier to support.

---

## 8. Release Blockers

The following should be treated as blockers before tagging the first release:

1. DTB / overlay / boot-config contradiction
2. IOMMU status contradiction
3. version mismatch (`0.9.8` vs `1.0`)
4. missing root license file
5. missing changelog / release notes
6. no fresh-install validation record

---

## 9. Final Recommendation

Do **not** spend the next session on more optimization first.

The best next step is:
- decide the authoritative install/runtime story
- align docs and installer with that truth
- add missing release artifacts
- validate on a fresh system
- only then cut the first release

That will produce a much cleaner and more trustworthy `v1.0.0` than adding more technical work before the repo itself is coherent.
