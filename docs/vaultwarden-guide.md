# Vaultwarden Integration Guide

## Architecture

```
Organization: tatra.dev (c2c3237d-a1e3-4063-8a85-5672493d8418)
├── Collections (access control per machine)
│   ├── dmbot    (d4a0155f...)  — laptop
│   └── atmanam  (be8c9cc3...)  — server
│
├── Folders (type labels, NOT access control)
│   ├── .ssh  (32b589bb...)  — SSH keys (type 5)
│   └── .env  (1720d1da...)  — env vars (type 2)
│
└── Items (each = separate per collection)
    ├── .ssh/
    │   ├── github.com    → dmbot       (type 5, ed25519)
    │   ├── github.com    → atmanam     (type 5, ed25519)
    │   ├── atmanam       → dmbot       (type 5)
    │   ├── orangebot     → dmbot       (type 5)
    │   ├── serpspot      → dmbot       (type 5, RSA)
    │   └── testbot       → dmbot       (type 5)
    └── .env/
        ├── GIT_USER_NAME     → dmbot
        ├── GIT_USER_NAME     → atmanam
        ├── GIT_USER_EMAIL    → dmbot
        ├── GIT_USER_EMAIL    → atmanam
        ├── BT_HEADPHONES_MAC → dmbot
        ├── BT_MOUSE_MAC      → dmbot
        ├── Z_AI_API_KEY      → dmbot
        └── Z_AI_API_KEY      → atmanam
```

## Rules

1. **One item per collection** — NEVER put 2 collectionIds on one item. Separate items = separate control.
2. **organizationId is MANDATORY** — items without it don't show in UI folders/collections.
3. **folderId is MANDATORY** — `.ssh` for SSH keys, `.env` for env vars. Labels the item type.
4. **BW CLI version pinned** — `2026.3.0` (2026.4.0 was supply-chain attacked, 2026.4.2 has VW compat issues).
5. **Login pattern** — always `BW_PASSWORD="$PASS" bw login --passwordenv BW_PASSWORD`, never `--raw` or stdin.
6. **Secrets never in stdout** — use `vw-safe` wrapper, `read -s` for passwords, `unset` after use.

## Item Types

### SSH Key (type 5) — `.ssh` folder

Native BW SSH Key item. Key material in structured fields, NOT in notes.

```
{
  type: 5,
  name: "<alias>",
  folderId: "<.ssh-folder-id>",
  organizationId: "<org-id>",
  collectionIds: ["<single-collection-id>"],
  sshKey: {
    privateKey: "<key-content>",
    publicKey: "<pubkey-content>"
  },
  fields: [
    {name: "filename",     value: "id_ed25519"},
    {name: "Host",         value: "github.com"},
    {name: "HostName",     value: "github.com"},
    {name: "User",         value: "git"},
    {name: "Port",         value: ""},
    {name: "IdentityFile", value: "~/.ssh/id_ed25519"},
    {name: "Extra",        value: "IdentitiesOnly yes"}  // multi-line OK
  ]
}
```

### Env Var (type 2) — `.env` folder

Secure Note with name = env var name, notes = value.

```
{
  type: 2,
  name: "<UPPERCASE_VAR_NAME>",
  folderId: "<.env-folder-id>",
  organizationId: "<org-id>",
  collectionIds: ["<single-collection-id>"],
  notes: "<value>",
  secureNote: {type: 0}
}
```

## CLI Reference

### Create item (always via template + encode)

```bash
# Env var
bw get template item | jq \
  --arg name "VAR_NAME" \
  --arg value "secret-value" \
  --arg fid "$ENV_FOLDER_ID" \
  --arg oid "$ORG_ID" \
  --argjson coll "[\"$COLLECTION_ID\"]" \
  '.type = 2 | .secureNote.type = 0 | .name = $name | .notes = $value | .folderId = $fid | .organizationId = $oid | .collectionIds = $coll' \
  | bw encode | bw create item --session "$BW_SESSION"

# SSH key — use ssh-backup utility (handles type 5 correctly)
ssh-backup --org "$ORG_ID" --collection "$COLLECTION_ID" ~/.ssh/id_ed25519
```

### Login pattern (never use --raw)

```bash
# Interactive (source to export BW_SESSION)
source vw-connect

# Script
VW_URL="https://vw.example.com"
BW_EMAIL="user@example.com"
BW_PASS="<read -s>"
bw config server "$VW_URL"
BW_PASSWORD="$BW_PASS" bw login "$BW_EMAIL" --passwordenv BW_PASSWORD
export BW_SESSION=$(BW_PASSWORD="$BW_PASS" bw unlock --passwordenv BW_PASSWORD --raw)
unset BW_PASS
bw sync --session "$BW_SESSION"
```

### Daily use (from zsh)

```bash
source vw-connect          # interactive login
bwenv Z_AI_API_KEY         # export env var to shell
bwget github.com            # print SSH private key
```

### Safe exploration (no secrets leaked)

```bash
vw-safe list collections
vw-safe list items collection <id>
vw-safe get <item-id>
```

## Key Rotation Procedures

### Rotate SSH key

```bash
# 1. Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new -C "user@host"

# 2. Deploy public key to target host
ssh-copy-id -i ~/.ssh/id_ed25519_new.pub user@hostname

# 3. Update VW (ssh-backup handles update if item exists)
ssh-backup --org "$ORG_ID" --collection "$COLLECTION_ID" ~/.ssh/id_ed25519_new

# 4. Re-run bootstrap VW section or manually deploy
#    New key will overwrite old one on next bootstrap

# 5. Remove old key after verifying new one works
ssh -i ~/.ssh/id_ed25519_new user@hostname  # test
rm ~/.ssh/id_ed25519_old
```

### Rotate API token

```bash
# 1. Generate new token in provider UI

# 2. Update VW
env-backup --org "$ORG_ID" --collection "$COLLECTION_ID" API_TOKEN_NAME
# Enter new value when prompted

# 3. Update current shell
bwenv API_TOKEN_NAME

# 4. Revoke old token in provider UI
```

### Agent-assisted rotation

When an agent needs to rotate keys/tokens:

1. Agent generates new credential
2. Agent uses `env-backup` or `ssh-backup` to update VW
3. Agent verifies new credential works
4. Agent reports completion — user revokes old credential manually

**Agent MUST NOT revoke old credentials automatically.** Always human-verified.

## Bootstrap Integration

Module `08-secrets-auth.sh` handles VW during bootstrap:

1. Installs BW CLI (pinned version)
2. Asks if user wants to configure VW
3. Login via `--passwordenv` pattern
4. Lists collections → user selects one
5. Pulls env vars from selected collection (UPPERCASE type 2 → exports)
6. Pulls SSH keys from selected collection (type 5 → ~/.ssh/ + config)
7. Saves session to `$STATE_DIR/bw-session`

## Files

| File | Purpose |
|------|---------|
| `scripts/bin/vw-connect` | Interactive VW login → BW_SESSION |
| `scripts/bin/vw-safe` | Safe bw wrapper (no secrets in output) |
| `scripts/bin/ssh-backup` | Save SSH key → VW type 5 |
| `scripts/bin/env-backup` | Save env var → VW type 2 |
| `zsh/.zshrc` (bwget/bwenv) | Daily shell functions |
| `scripts/modules/08-secrets-auth.sh` | Bootstrap VW integration |
