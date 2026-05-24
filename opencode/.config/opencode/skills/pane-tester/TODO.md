# pane-tester — TODO

**Current Version:** 0.6  
**Next Target:** v0.7 (~900 lines)

---

## ✅ v0.6 Completed (2026-02-25)

| Metric | v0.5 | v0.6 | Change |
|--------|------|------|--------|
| Lines | 1181 | 1034 | -147 (-12%) |
| Examples | 4 | 4 | 0 |

### Done
- ✅ Simplify Watchdog section - moved detailed examples to examples/ (~100 lines)
- ✅ Shorten Parallel Testing section - moved to examples/ (~25 lines)

---

## ✅ v0.5 Completed (2026-02-25)

| Metric | v0.45 | v0.5 | Change |
|--------|-------|------|--------|
| Lines | 1422 | 1181 | -241 (-17%) |
| Examples | 3 | 4 | +1 |

### Done
- ✅ Extract Delegated Testing examples to `examples/delegated-testing-details.md` (~200 lines)
- ✅ Consolidate Test Plan formats - moved Strict format to examples/ (~50 lines)
- ✅ Shorten Result Report example - kept minimal in SKILL.md (~40 lines)
- ✅ Move Generate Test Plan helper to examples/ (~50 lines)

---

## ✅ v0.45 Completed (2026-02-25)

| Metric | v0.2 | v0.45 | Change |
|--------|------|-------|--------|
| Lines | 1556 | 1422 | -134 (-8.6%) |
| Duplicates | 4 | 0 | ✅ |
| Examples | 1 | 3 | +2 |

### Done
- Remove duplicate Purpose sections (3 → 1)
- Remove duplicate Workflow Template (2 → 1)
- Remove duplicate Delegation Architecture (2 → 1)
- Remove duplicate Test Plan example (2 → 1)
- Fix window_create pane_id extraction bug
- Consolidate decision matrices/tables
- Reduce debug_mode section (~50 lines)
- Create examples/generic-test.md
- Create examples/delegation.md

---

## 📊 Total Progress

| Metric | v0.2 | v0.6 | Change |
|--------|------|------|--------|
| Lines | 1556 | 1034 | -522 (-34%) |
| Duplicates | 4 | 0 | ✅ |
| Examples | 1 | 4 | +3 |

---

## 🔵 v0.7 TODO

### 1. Move Delegation Feature Flags to examples/

**Current state:** ~15 lines at end of SKILL.md

**Action:** Move to examples/delegated-testing-details.md

**Expected savings:** ~15 lines

---

### 2. Remove trailing timestamps

**Current state:** `*Delegated testing added: $(date)*` at end

**Action:** Remove unnecessary timestamp lines

**Expected savings:** ~5 lines

---

## 📊 v0.7 Target

| Metric | v0.6 | v0.7 Target | Change |
|--------|------|-------------|--------|
| Lines | 1034 | ~1000 | -34 (-3%) |

---

---

## 🔬 Research & Testing

### Research Tasks

| # | Task | Status |
|---|------|--------|
| 1 | Find best practices for writing skills (web search) | ⬜ Pending |
| 2 | Find how to analyze/evaluate skills | ⬜ Pending |
| 3 | Create separate skill-skill based on findings | ⬜ Pending |

### Self-Analysis Tasks

| # | Task | Status |
|---|------|--------|
| 4 | Analyze pane-tester skill against best practices | ⬜ Pending |
| 5 | Identify non-obvious issues in SKILL.md | ⬜ Pending |
| 6 | Identify obvious improvements | ⬜ Pending |

### Real-World Testing

| # | Task | Status |
|---|------|--------|
| 7 | Test pane-tester on real example (vpsemu?) | ⬜ Pending |
| 8 | Document test results and findings | ⬜ Pending |

---

## 🟢 Future (v0.8+)

- Add `pane_screenshot` command (capture pane as image)
- Add `test_parallel` command (run multiple tests simultaneously)
- Add integration with CI/CD systems
- Create `examples/vpsemu-test.md` — real-world example

---

*Last updated: 2026-02-25*
