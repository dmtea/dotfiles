# Rule: Action Logging

**ID:** `action-logging`
**Version:** 1.0
**Updated:** 2026-03-25

---

## Purpose

Ensure all significant actions, configurations, and architectural decisions are documented for future reference and troubleshooting.

---

## What to Log

**Always log:**
- Service setup/deployment (new services, migrations)
- Configuration changes (especially security-related)
- Infrastructure changes (networking, DNS, tunnels)
- Backup/restore procedures
- Access credentials setup (not the credentials themselves!)
- Architecture decisions and rationale

**Log format:**
```markdown
# [Service/Component Name] Setup

**Date:** YYYY-MM-DD
**Host:** where it runs
**Service:** what it is

---

## What
[What was done]

## Why
[Why this approach was chosen]

## How
[Technical details, files, commands]

## Files
[List of relevant files]

## Commands
[Useful commands for management]

## Verification
[How to verify it works]

## Related
[Links to plans, repos, other docs]
```

---

## Where to Log

| Type                    | Location                          |
| ----------------------- | --------------------------------- |
| Project-level actions   | `project/docs/`                   |
| Service setup           | `project/docs/{service-name}.md`  |
| Infrastructure changes  | `project/docs/infrastructure.md`  |
| Personal/home setup     | `~/docs/{topic}.md`               |

---

## When to Log

**Immediately after:**
- Completing a setup task
- Making a configuration change
- Solving a non-trivial problem
- Making an architectural decision

**NOT after:**
- Trivial changes (typo fixes)
- Routine operations
- Temporary debugging

---

## Examples

### Good: Service Setup Log

```markdown
# Vaultwarden Backup Setup

**Date:** 2026-03-25
**Host:** Orange Pi (orangebot)

## What
Weekly automated backup of Vaultwarden data to laptop.

## Why
Orange Pi could fail; need off-site copy of password database.

## How
- Laptop pulls backup via SSH (not push from OPI)
- systemd timer with Persistent=true (runs if laptop was off)
- Stops container for consistent backup

## Files
- ~/backups/orangebot-vw/pull-vaultwarden-backup.sh
- ~/.config/systemd/user/vaultwarden-backup.{service,timer}
```

### Good: Decision Log

```markdown
# Decision: Cloudflare Tunnel vs ngrok

**Date:** 2026-03-25

## Choice
Cloudflare Tunnel

## Why
- Free, no bandwidth limits
- Own domain (vw.tatra.dev)
- More stable than ngrok free tier
- Can manage via CLI (good for Ansible later)

## Trade-offs
- Requires domain on Cloudflare
- More setup than ngrok
```

---

## Relation to Other Rules

- Combine with `doc-freshness-sync` for library documentation
- This rule is for **actions and decisions**, not reference docs

---

## Checklist

After completing a significant action:

- [ ] Created doc in appropriate location
- [ ] Included: what, why, how
- [ ] Listed relevant files
- [ ] Added verification steps
- [ ] Linked to related docs/plans
