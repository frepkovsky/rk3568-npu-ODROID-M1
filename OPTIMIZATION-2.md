# RKNPU Driver Optimization Backlog — Current State

This document lists the optimization work that is either already part of the accepted codebase or still remains as real follow-up work.

---

## Current Landed Optimizations

These optimizations are already in the accepted codebase and should be treated as the current baseline, not as open work:

- `rknpu_job` allocation uses a `kmem_cache`
- DKMS GEM tracking range objects use a `kmem_cache`
- misc-device session memory objects are indexed by `obj_addr` hash for faster lookup
- `MEM_SYNC` uses a single-SG fast path when `sgt->nents == 1`
- DKMS devfreq status uses sampled busy time with an active fallback when sampled load is zero
- the DKMS devfreq path is SCMI-only
- `/dev/rknpu` direct allocation is implemented and validated
- DRM GEM create/map and misc direct-allocation runtime probes are validated on the target board

---

## Remaining Cleanup Work

### 1. Remove old kernel compatibility branches — Completed

- **Status:** completed in `1d45258` (`drivers: drop remaining KERNEL_VERSION guards`)
- **Files:** `drivers/rknpu/include/rknpu_iommu.h`
- **Validation:** rebuilt locally on `m1`, rebooted, passed runtime markers, `tests/test_direct_alloc.c`, `tests/test_drm_gem.c`, and idle-aware pinned benchmark (`84.6 ms`, `11.8 FPS`)

### 2. Flatten remaining `CONFIG_NO_GKI` branching — Completed

- **Status:** completed in `1d2b705` (`drivers: flatten remaining CONFIG_NO_GKI paths`) plus `8d317dc` (`drivers: make gem cache sync dkms-safe`)
- **Files:** `drivers/rknpu/rknpu_gem.c`, `drivers/rknpu/rknpu_iommu.c`
- **Validation:** rebuilt locally on `m1`, rebooted, passed runtime markers, `tests/test_direct_alloc.c`, `tests/test_drm_gem.c`, and idle-aware pinned benchmark (`84.6 ms`, `11.8 FPS`)

---

## Remaining Performance Work

### 1. Replace linear GEM address lookup with a hash table — Completed

- **Status:** completed in `e48323e` (`drivers: hash dkms gem address lookups`)
- **File:** `drivers/rknpu/rknpu_gem.c`
- **Validation:** rebuilt locally on `m1`, rebooted, passed runtime markers, `tests/test_direct_alloc.c`, `tests/test_drm_gem.c`, and idle-aware pinned benchmark (`84.6 ms`, `11.8 FPS`)

### 2. Short-circuit the self-owned DMA-BUF attach/map round trip

- **File:** `drivers/rknpu/rknpu_mem.c`
- **Current state:** direct allocation is implemented and working, but still goes through the generic attachment and mapping path
- **Why it remains:** self-owned buffers still pay framework overhead
- **Expected value:** medium on allocation-heavy workflows
- **Risk:** medium because DMA-BUF export semantics must remain correct

### 3. Add a buffer pool for repeated allocation-heavy workloads

- **File:** `drivers/rknpu/rknpu_mem.c`
- **Current state:** allocations are still created on demand
- **Why it remains:** repeated model load and teardown paths may still benefit even if steady-state inference does not
- **Expected value:** medium for repeated load/unload patterns
- **Risk:** medium to high due to lifetime accounting and fragmentation policy

### 4. Simplify the load-accounting story

- **Files:** `rknpu_devfreq_dkms.c`, `rknpu_drv.c`, `rknpu_debugger.c`
- **Current state:** devfreq now uses busy-time accounting plus active fallback, while debug reporting still exposes timer-based load separately
- **Why it remains:** the runtime behavior is good, but the model is still more complex than ideal
- **Expected value:** clarity first, minor runtime value second
- **Risk:** low to medium

---

## Validation Priorities

These are still useful ongoing checks even though the core runtime state is already established:

- rebuild locally on the ODROID-M1 itself after `git pull`
- keep smoke-test assets in persistent repo-local paths such as `project/rknn_model_zoo/src`, not `/tmp`
- validate on a fresh supported Armbian image
- keep using the idle-aware pinned benchmark wrapper for performance comparisons
- keep validating both the misc path and the DRM render-node path after risky changes

---

## Out of Scope

These are intentionally not part of the active optimization backlog here:

- anything already implemented in the accepted codebase
- clocks above `1000 MHz`
- speculative PVTPLL enablement on RK3568
- application-level zero-copy pipeline redesign outside this driver
- kernel-side work that must be fixed outside this repository

---

## Suggested Order

1. release-safe cleanup (`KERNEL_VERSION`, `CONFIG_NO_GKI`)
2. GEM address lookup improvement
3. direct-allocation path simplification
4. allocation pooling only if allocation-heavy workloads justify it
5. load-accounting simplification if it improves clarity without hurting runtime behavior
