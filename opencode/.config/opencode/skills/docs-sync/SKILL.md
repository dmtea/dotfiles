---
name: docs-sync
version: 1.0
description: >
  Documentation freshness checking and local docs management.
  Automatically manages cloned documentation repositories with freshness tracking.
  TRIGGERS: library docs, framework docs, check docs, local docs, docs-sync,
  documentation for, how to use [library], [library] documentation, API docs
tools: [Bash, Read]
---

# docs-sync Skill

Manage local documentation copies with automatic freshness checking and git-based synchronization.

## When to Use

Invoke this skill when:
- User asks about a library/framework and you need reference documentation
- User mentions "local docs", "docs-sync", or asks to check documentation freshness
- You need up-to-date API reference for a library in project dependencies
- User wants to clone or manage documentation locally

## Parallel Usage

**IMPORTANT**: Use docs-sync IN PARALLEL with Librarian agent's MCP tools (context7, websearch, grep_app):

```
User asks about library X
    │
    ├─► Check docs-sync manifest (instant)
    │    └─► If fresh → Use local docs immediately
    │
    ├─► Fire librarian (background) with MCP tools
    │    └─► context7, websearch, grep_app
    │
    └─► Collect results from all sources
         └─► Merge: local (fast) + MCP (comprehensive)
```

**Priority**: Local docs first (instant) → MCP as fallback/enrichment

## Locations

| Item        | Path                                          |
| ----------- | --------------------------------------------- |
| Script      | `~/.config/opencode/skills/docs-sync/bin/docs-sync` |
| Config      | `~/.config/opencode/skills/docs-sync/config.json`   |
| Manifest    | `~/.cache/ai_docs_sync/.manifest.json`              |
| Cloned docs | `~/.cache/ai_docs_sync/docs/`                       |

## Configuration

Edit `~/.config/opencode/skills/docs-sync/config.json`:

```json
{
  "preferred_languages": ["en", "ru"],
  "default_sparse_paths": ["docs/", "README.md", "CHANGELOG.md"],
  "default_branch": "auto",
  "default_ttl_hours": 24,
  "language_cleanup": {
    "enabled": true
  }
}
```

## Commands

### Add docs repository

```bash
# Basic usage
docs-sync add <name> <url>

# With options
docs-sync add nextjs https://github.com/vercel/next.js \
    --branch dev \
    --sparse packages/web/src/content/docs/,README.md \
    --langs en,ru

# Pin to specific version
docs-sync add vue https://github.com/vuejs/vue --pin v3.4.0
```

**Options:**
- `--sparse <paths>` — Comma-separated paths to checkout (default: docs/,README.md,CHANGELOG.md)
- `--branch <name>` — Branch to track (default: auto-detect)
- `--pin <version>` — Pin to specific tag/commit
- `--langs <codes>` — Languages to keep (default: en,ru from config)

### Update docs

```bash
# Update all stale docs
docs-sync update

# Update specific repo
docs-sync update nextjs

# Force refresh
docs-sync update --force
```

### List tracked docs

```bash
docs-sync list
docs-sync list --stale    # Only stale
docs-sync list --json     # JSON output
```

### Remove docs

```bash
docs-sync remove <name>
```

### Configuration

```bash
docs-sync config show      # Show current config
docs-sync config edit      # Open in editor
docs-sync config path      # Show config file path
```

## Freshness Protocol

### TTL Thresholds

| Data Type                    | TTL      | Reason            |
| ---------------------------- | -------- | ----------------- |
| Versioned docs (`v1.2.3`)    | 7 days   | Immutable         |
| Latest docs (no version)     | 24 hours | May update        |
| Beta/canary releases         | 4 hours  | Frequent changes  |
| Package versions (npm/pypi)  | 1 hour   | New releases      |
| GitHub code examples         | 24 hours | Relatively stable |

### Decision Flow

```
User asks about library X
    │
    ├─► Check manifest for X
    │    │
    │    ├─► Found + fresh (age < TTL)
    │    │    └─► Use local docs at ~/.cache/ai_docs_sync/docs/X/
    │    │
    │    ├─► Found + stale (age >= TTL)
    │    │    └─► Run `docs-sync update X`, then use
    │    │
    │    └─► Not found
    │         │
    │         ├─► In project deps?
    │         │    └─► Offer to add: `docs-sync add X <url>`
    │         │
    │         └─► One-off question?
    │              └─► Use MCP tools (context7, websearch)
    │
    └─► User requests refresh
         └─► `docs-sync update --force`
```

## Reading Local Docs

When docs exist locally, read them directly:

```bash
# List available docs
ls ~/.cache/ai_docs_sync/docs/<name>/

# Read specific doc
Read: ~/.cache/ai_docs_sync/docs/<name>/packages/web/src/content/docs/cli.mdx
```

## Language Cleanup

After cloning, unwanted language directories are automatically removed based on `preferred_languages` config.

Default: `["en", "ru"]` — keeps English and Russian, removes others (ar, de, fr, ja, etc.)

This reduces storage by ~80% for multilingual docs.

## Integration with Agents

### For Sisyphus (primary agent)

When user asks about a library:
1. Check manifest: `docs-sync list --json | jq '.docs | keys'`
2. If found + fresh → Read local docs
3. If not found → Offer to clone, fire librarian in parallel

### For Librarian (sub-agent)

Pass via `load_skills`:
```typescript
task(
  subagent_type="librarian",
  load_skills=["docs-sync"],
  run_in_background=true,
  prompt="Find documentation for React hooks..."
)
```

## Examples

### Scenario: User asks about Next.js App Router

```bash
# 1. Check if we have Next.js docs
docs-sync list | grep nextjs

# 2. If not, offer to clone
docs-sync add nextjs https://github.com/vercel/next.js \
    --branch dev \
    --sparse packages/web/src/content/docs/,README.md \
    --langs en,ru

# 3. Read relevant docs
Read: ~/.cache/ai_docs_sync/docs/nextjs/packages/web/src/content/docs/app.mdx
```

### Scenario: User says "check docs for React"

```bash
# 1. Check freshness
docs-sync list

# 2. If stale, update
docs-sync update react

# 3. Read docs
Read: ~/.cache/ai_docs_sync/docs/react/...
```

## Troubleshooting

**No files after clone:**
- Check `--sparse` paths match repo structure
- Use `--branch` if default branch differs

**Language cleanup too aggressive:**
- Edit `config.json`: `"language_cleanup.enabled": false`
- Or add more languages: `"preferred_languages": ["en", "ru", "de"]`

**Wrong branch detected:**
- Use explicit `--branch main` or `--branch dev`
