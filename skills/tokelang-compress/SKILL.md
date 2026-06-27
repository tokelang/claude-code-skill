---
name: tokelang-compress
description: >
  Compress a context file (CLAUDE.md, .cursorrules, agent persona, RAG header, etc.) in
  place with an automatic .original.md backup. Uses the local Tokelang engine (OptA→MEC)
  in default mode for code-dense instruction docs; validator-gated, with negations and
  protected spans preserved. Reversible via /tokelang-restore.
  Trigger: /tokelang-compress <filepath>
---

# Compress a context file

Compresses a context file with the local engine's **default mode (the OptA→MEC chain)**. Config/instruction files (CLAUDE.md, `.cursorrules`, agent personas) are *code-dense*, and the engine's `context_file` mode passes them through at near-0% — so this command uses `default`, which compresses them ~17–31% while the validator preserves negations, numbers, code, URLs, and other protected spans. (`--mode context_file` is the right choice only for *prose-heavy* system prompts / RAG headers, where its higher recall floor applies without no-opping.)

The original file is preserved as `<filename>.original.md` in the same directory. You can revert any time via `/tokelang-restore <filepath>`.

## Trigger

- `/tokelang-compress <filepath>` — explicit
- "compress my CLAUDE.md" — natural language
- "shrink this context file" — natural language

## Process

1. Verify the file exists and is a supported type (`.md`, `.txt`, `.rst`, or extensionless markdown). Code/config files (`.json`, `.yaml`, `.toml`, `.py`, `.rs`) are explicitly rejected — wrong target for context compression.

2. Read the file and check size. Files <500 chars are usually not worth compressing; warn and ask before proceeding.

3. Run the local Tokelang binary in default mode (OptA→MEC):
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/bin/tokelang-cli" compress --mode default < <filepath>
   ```
   (For a prose-heavy system-prompt file rather than a code-dense instruction doc, use `--mode context_file` instead.)

4. The engine is validator-gated: it returns the compressed form only when the content-recall floor holds and every protected span survives — negations, numbers, fenced code (byte-identical), URLs, inline code, contract vocab. If any check fails, the engine passes the **original through unchanged**, so a rejected compression simply yields the original file, never a lossy one.

5. Write the compressed version over the original file. Save the original as `<filename>.original.md` (a Claude Code marker file — do not edit by hand).

6. Print a summary:
   ```
   Compressed CLAUDE.md
   Before: 1,247 tokens (cl100k_base)
   After:  812 tokens
   Saved:  435 tokens (35%)
   Backup: CLAUDE.md.original.md
   ```

## What this command does NOT do

- Compress code files (use file type guard; rejects `.json`, `.yaml`, `.toml`, etc.)
- Auto-compress without user-initiated trigger
- Modify the file in any way other than running it through the engine
- Send file contents to the hosted API (local engine only)

## Failure modes (and how the tool handles them)

| Situation | Behavior |
|---|---|
| File doesn't exist | Error: print path and abort |
| File is wrong type | Error: explain that context_file mode is for prose, suggest manual editing |
| File <500 chars | Warn + ask confirmation; small files yield small savings |
| Validator rejects compression | Print the failed invariant; leave original file untouched; suggest user review |
| `.original.md` already exists | Ask whether to overwrite the existing backup |

## Example

```
> /tokelang-compress CLAUDE.md

Reading CLAUDE.md... 1247 cl100k tokens.
Compressing in context_file mode...
Validator: recall 0.91 ✓ | headings 7/7 ✓ | code blocks 3/3 ✓ | URLs 4/4 ✓
Writing compressed file (812 tokens).
Backup saved to CLAUDE.md.original.md.

Saved 435 tokens (35%). Restore with: /tokelang-restore CLAUDE.md
```
