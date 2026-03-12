# PLAN2 — Current Release and Documentation Roadmap

This file captures the current remaining release work after the driver, installer, and core runtime documentation have already been aligned to the accepted codebase.

---

## 1. Current Project Position

The repository is now in a much cleaner state than the earlier planning phase.

### Already established

- user-facing install and verification docs describe the current supported boot model
- `FEATURES.md` reflects the current runtime and validated feature set
- `OPTIMIZATION-2.md` distinguishes landed optimizations from remaining work
- the accepted optimization stack is already part of `main`
- runtime validation exists for misc direct allocation, DRM GEM create/map, and idle-aware benchmarks on the target board

### Still worth finishing before a polished public release

- add missing release artifacts such as a root `LICENSE` file and release notes
- add a clean validation document for fresh-system testing
- decide how versioning is presented to users when DKMS package version and runtime driver string differ
- keep internal or historical documents clearly separate from user-facing docs

---

## 2. Documentation Roles

The top-level documentation should now be treated as follows:

- `README.md`
  - authoritative install, verify, support, and limitation document
- `FEATURES.md`
  - technical capability matrix and runtime feature inventory
- `OPTIMIZATION-2.md`
  - current optimization backlog only
- `AGENTS.md`
  - contributor and assistant context only
- `PLAN2.md`
  - current release and documentation roadmap

Historical planning or investigation notes should stay clearly framed as internal history rather than active release guidance.

---

## 3. Remaining Release Deliverables

### High priority

1. Add a root `LICENSE`
2. Add `CHANGELOG.md` or `RELEASE_NOTES.md`
3. Add a release-oriented validation document

### Good follow-up

1. Add a dedicated uninstall or rollback document if the README section proves too short
2. Add a concise support matrix and validation checklist document for new users
3. Mark purely historical docs more explicitly if they remain in the repository

---

## 4. Validation Roadmap

The release validation flow should document one supported reference environment and one repeatable pass criteria set.

### Reference environment

- board: ODROID-M1 8 GB
- OS family: Armbian May 2026 release stream or newer
- kernel baseline: `6.18.9-current-rockchip64`
- RKNN SDK/runtime: `2.4.0`

### Minimum validation checklist

1. install dependencies
2. run `install.sh`
3. reboot
4. confirm `rknpu` and `dma32_heap` are loaded
5. confirm `/dev/rknpu`
6. confirm `/dev/dri/by-path/platform-fde40000.npu-render`
7. confirm `/dev/dma_heap/system -> /dev/dma_heap/dma32`
8. confirm `/sys/class/devfreq/fde40000.npu`
9. run `tests/test_direct_alloc.c`
10. run `tests/test_drm_gem.c`
11. run at least one benchmark or smoke test

### Benchmark guidance

Use the idle-aware pinned wrapper for driver performance comparisons:

- `tests/bench_yolov5_pinned.sh`

That benchmark path is the current accepted measurement baseline for regression checks.

---

## 5. Versioning Note

The repository currently has two version identifiers with different meanings:

- DKMS package version: `1.0`
- runtime driver string: `0.9.8`

That is acceptable if it is documented consistently. The remaining work is not to change it blindly, but to describe it clearly in release-oriented docs and release notes.

---

## 6. Post-Release Engineering Track

These items remain useful after documentation and release artifacts are complete:

### Cleanup

- remove old kernel compatibility guards
- remove `FPGA_PLATFORM` guards
- remove `CONFIG_NO_GKI` guards

### Performance follow-up

- hash table for GEM address lookup
- simplify the self-owned DMA-BUF attach and map path
- evaluate a buffer pool only if allocation-heavy workloads justify it
- reduce complexity in the load-accounting story only if it stays runtime-neutral

---

## 7. Recommended Next Steps

1. add the missing release artifacts
2. add the fresh-system validation document
3. keep user docs minimal and authoritative
4. leave historical investigation details out of release-facing docs
5. continue cleanup and optimization work only after the release surface is complete
