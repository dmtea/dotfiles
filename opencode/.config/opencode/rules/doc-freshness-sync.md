# Rule: Documentation Freshness & Sync System

**ID:** `doc-freshness-sync`  
**Version:** 1.1.0  
**Updated:** 2026-02-26  
**Skill:** `docs-sync` — Load via `load_skills=["docs-sync"]` or invoke directly

---

## Quick Reference

| Item        | Location                                              |
| ----------- | ----------------------------------------------------- |
| CLI         | `docs-sync` (in PATH)                                 |
| Skill       | `~/.config/opencode/skills/docs-sync/`                |
| Config      | `~/.config/opencode/skills/docs-sync/config.json`     |
| Manifest    | `~/.cache/ai_docs_sync/.manifest.json`                |
| Cloned docs | `~/.cache/ai_docs_sync/docs/`                         |

---

## When to Apply

Apply this rule when user asks about:
- Config-specific settings (opencode.json, tsconfig, etc.)
- Library/framework usage (npm packages, APIs, SDKs)
- Anything time-sensitive or in active development
- Version-specific behavior

---

## TTL Summary

| Type               | TTL      |
| ------------------ | -------- |
| Versioned docs     | 7 days   |
| Latest docs        | 24 hours |
| Beta/canary        | 4 hours  |
| Package versions   | 1 hour   |

---

## Decision Flow

```
User asks about library X
    │
    ├─► Check manifest: docs-sync list --json
    │
    ├─► Found + fresh → Use local docs
    │    └─► Read: ~/.cache/ai_docs_sync/docs/X/...
    │
    ├─► Found + stale → Update first
    │    └─► docs-sync update X
    │
    └─► Not found → Offer to clone
         └─► docs-sync add X <url> --langs en,ru
```

---

## Parallel with MCP Tools

**ALWAYS run in parallel with Librarian's MCP tools:**

```
User asks about library X
    │
    ├─► docs-sync check (instant)
    ├─► librarian → context7, websearch, grep_app (background)
    │
    └─► Merge results: local (fast) + MCP (comprehensive)
```

**Priority**: Local docs first → MCP as fallback/enrichment

---

## Commands

```bash
# Add docs
docs-sync add <name> <url> [--branch <name>] [--langs en,ru]

# Update
docs-sync update [--force]

# List
docs-sync list [--stale]

# Config
docs-sync config show
```

---

## Full Documentation

See skill: `~/.config/opencode/skills/docs-sync/SKILL.md`
