---
name: tokelang-restore
description: >
  Restore a context file from its .original.md backup created by /tokelang-compress.
  Reverses any compression performed on the file.
  Trigger: /tokelang-restore <filepath>
---

# Restore a compressed file

Reverses `/tokelang-compress` by replacing the compressed file with its `.original.md` backup. The backup file is deleted after successful restoration.

## Trigger

- `/tokelang-restore <filepath>` — explicit
- "undo tokelang on CLAUDE.md" — natural language
- "restore the original" (only if context makes the target file unambiguous) — natural language

## Process

1. Verify `<filepath>.original.md` exists. If not, abort with: "No backup found for <filepath>. Was this file compressed by Tokelang?"

2. Verify `<filepath>` exists and was compressed (we expect a marker comment at the top of compressed files — TBD format).

3. Replace `<filepath>` with the contents of `<filepath>.original.md`.

4. Delete `<filepath>.original.md` after successful copy.

5. Print confirmation:
   ```
   Restored CLAUDE.md from CLAUDE.md.original.md.
   Backup deleted.
   ```

## What this command does NOT do

- Restore from arbitrary backups (only `.original.md` siblings)
- Restore files that were never compressed by Tokelang
- Auto-trigger when the model touches a compressed file (user must invoke)

## Failure modes

| Situation | Behavior |
|---|---|
| No `.original.md` backup exists | Error: explain and abort |
| File doesn't show our compression marker | Warn: "This file may not have been compressed by Tokelang. Restore anyway? (y/n)" |
| Backup older than compressed file (modified-after-compression) | Warn: "You may have edited the compressed version since. Restore will lose your edits. Proceed? (y/n)" |
| Backup file is empty | Error: backup looks corrupted; abort |

## Example

```
> /tokelang-restore CLAUDE.md

Restored CLAUDE.md (1247 cl100k tokens) from CLAUDE.md.original.md.
Backup deleted.
```
