# RKNPU Driver Optimization Opportunities — Cleaned Current State

> This document intentionally lists only optimization and cleanup work that is still open or still worth discussing.
> Solved items, stale assumptions, and rejected ideas are not repeated here.

---

## Current Verified Code State

These points are already reflected in the current codebase and therefore are **not** part of the remaining optimization backlog:

- `power_put_delay_ms` already defaults to `500` and is already a module parameter
- `rknpu_soft_reset()` and `rknpu_job_abort()` already use `msleep(10)`
- `rknpu_gem_free_object()` already no longer wraps teardown in `power_get` / `power_put`
- `rknpu_iommu_domain_get_and_switch()` already has a fast path for single-domain setups
- the DKMS devfreq path is already SCMI-only
- `/dev/rknpu` direct allocation is already implemented

What still remains is below.

---

## 1. Release-Safe Cleanup

These items improve readability and maintainability with low product risk.

### 1.1 Remove old kernel compatibility branches

- **Files:** multiple files under `drivers/rknpu/`
- **Evidence:** many `KERNEL_VERSION(...)` guards still exist for 4.x, 5.x, and early 6.x APIs
- **Why it still matters:** this DKMS module targets 6.18+ only; old branches make the code harder to audit and reason about
- **Expected value:** high maintenance payoff, no intended runtime change
- **Risk:** low if done mechanically and tested on the target kernel only

### 1.2 Remove `FPGA_PLATFORM` guards

- **Files:** `rknpu_drv.c`, `rknpu_reset.c`, `rknpu_debugger.c`
- **Evidence:** multiple `#ifndef FPGA_PLATFORM` branches are still present
- **Why it still matters:** this project does not target FPGA platforms
- **Expected value:** medium maintenance payoff
- **Risk:** low

### 1.3 Remove or flatten remaining `CONFIG_NO_GKI` branching

- **Files:** `rknpu_drv.c`, `rknpu_gem.c`, `rknpu_iommu.c`
- **Evidence:** `IS_ENABLED(CONFIG_NO_GKI)` still gates SRAM/NBUF-related paths and some IOMMU support logic
- **Why it still matters:** for this DKMS/Armbian target, these branches add complexity and hide the real active path
- **Expected value:** medium maintenance payoff
- **Risk:** low to medium, depending on whether any hidden dependency appears during test

---

## 2. Hot-Path Allocator and Lookup Work

These are the most credible remaining driver-side optimizations that are still open.

### 2.1 Use `kmem_cache` for `rknpu_job`

- **File:** `drivers/rknpu/rknpu_job.c`
- **Evidence:** `rknpu_job_alloc()` still uses `kzalloc(sizeof(*job), GFP_KERNEL)`
- **Why it still matters:** jobs are short-lived and allocated frequently
- **Expected value:** small but real hot-path improvement
- **Risk:** low

### 2.2 Use `kmem_cache` for GEM range tracking structs

- **File:** `drivers/rknpu/rknpu_gem.c`
- **Evidence:** GEM range tracking still does `kzalloc(sizeof(*r), GFP_KERNEL)`
- **Why it still matters:** fixed-size allocator churn is avoidable
- **Expected value:** low to medium
- **Risk:** low

### 2.3 Replace linear GEM address lookup with a hash table

- **File:** `drivers/rknpu/rknpu_gem.c`
- **Evidence:** `rknpu_dkms_find_gem_obj_by_addr()` still linearly scans `rknpu_dkms_gem_ranges`
- **Why it still matters:** this lookup sits on a real path and remains O(n)
- **Expected value:** medium
- **Risk:** medium because correctness of lookup and teardown must stay exact

### 2.4 Replace linear session scans in misc memory ioctls

- **File:** `drivers/rknpu/rknpu_mem.c`
- **Evidence:** `session->list` is still linearly scanned in object lookup and sync validation paths
- **Why it still matters:** repeated validation work grows with buffer count
- **Expected value:** low to medium
- **Risk:** medium

---

## 3. Buffer Allocation Path Work

### 3.1 Short-circuit the self-owned DMA-BUF attach/map round trip

- **File:** `drivers/rknpu/rknpu_mem.c`
- **Evidence:** after direct allocation with `dma_alloc_coherent()`, the code still performs `dma_buf_attach()` and `dma_buf_map_attachment()` on the same device path
- **Why it still matters:** this adds framework overhead for buffers the driver already owns
- **Expected value:** medium on allocation-heavy workflows
- **Risk:** medium because DMA-BUF export semantics must remain correct for userspace mmap and sharing

### 3.2 Buffer pool or cache for repeated allocations

- **File:** `drivers/rknpu/rknpu_mem.c`
- **Evidence:** allocations are still created on demand with no pooling layer
- **Why it still matters:** model load and setup overhead can benefit even if steady-state inference does not
- **Expected value:** medium for repeated load/unload workloads
- **Risk:** medium to high due to lifetime accounting and fragmentation policy

---

## 4. Devfreq Accuracy Work

### 4.1 Replace binary power-refcount load reporting with hardware-derived load

- **File:** `drivers/rknpu/rknpu_devfreq_dkms.c`
- **Evidence:** `rknpu_devfreq_get_dev_status()` still reports either `95/100` or `0/100` based only on `power_refcount`
- **Related existing support:** the driver already has `rknpu_get_rw_amount()` and related accounting paths
- **Why it still matters:** the current governor input is coarse and mostly binary
- **Expected value:** better scaling behavior and better power/performance balance
- **Risk:** medium because the new signal needs calibration

### 4.2 Revisit whether the load-tracking hrtimer is still justified

- **Files:** `rknpu_drv.c`, `rknpu_debugger.c`
- **Evidence:** debug load reporting still uses timer-based `busy_time`, while devfreq uses `power_refcount`
- **Why it still matters:** there are effectively two load stories in the driver
- **Expected value:** clarity first, minor runtime value second
- **Risk:** low once the intended load source is decided

---

## 5. Release-Blocking Reality Checks

These are not classic optimizations, but they are important because they affect what optimization work is even meaningful.

### 5.1 Verify the real M1 runtime state directly

Must be checked on the board, not only inferred from docs:

- whether the shipping install path really depends on the custom DTB
- whether `rknpu_dev->iommu_en` is actually `1` on the running target
- whether the attached IOMMU domain is active as expected
- whether devfreq and thermal throttling behave as documented on a fresh boot

### 5.2 Remove stale claims from planning/history docs

Optimization work should not continue to rely on outdated claims such as:

- custom DTB already removed
- stock DTB only install flow already final
- service cleanup already present in `install.sh` when it is not

---

## 6. Explicitly Out of Scope for This Remaining Optimization List

These items are intentionally excluded from the active backlog here:

- anything already implemented in the current code
- ideas blocked by kernel-side fixes outside this repo
- purely application-level pipelines such as full zero-copy camera to NPU to display work
- unsafe clock experiments above 1000 MHz
- speculative PVTPLL enablement for RK3568

---

## 7. Recommended Order

1. release-safe cleanup (`KERNEL_VERSION`, `FPGA_PLATFORM`, `CONFIG_NO_GKI`)
2. board truth verification on the real M1
3. GEM/session lookup improvements
4. allocator optimizations (`kmem_cache`)
5. DMA-BUF direct-allocation path simplification
6. devfreq load-signal improvement

The key point is: **do not optimize against stale assumptions**. First lock down what the M1 is really running, then optimize the code paths that are actually active.
