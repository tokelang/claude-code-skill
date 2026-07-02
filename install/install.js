#!/usr/bin/env node
/*
 * Tokelang Claude Code skill — NPX installer.
 *
 *   npx @tokelang-lite/claude-code-skill
 *
 * What it does (no external npm dependencies — built-in modules only):
 *   1. Detect this host's platform/arch and pick the matching release artifact name.
 *   2. Download that static engine binary from this repo's own `engine-v*` GitHub release,
 *      verify it against the release's combined SHA256SUMS, mark it executable.
 *   3. Assemble the plugin (skills + agents + hooks + statusline + resolver) at
 *      `~/.claude/skills/tokelang/`, dropping the binary into its `bin/`.
 *
 * Install target = a personal-scope *skills-directory plugin*: any folder under
 * `~/.claude/skills/` that has a `.claude-plugin/plugin.json` loads automatically as
 * `tokelang@skills-dir` on the next session — no `claude` CLI call, no marketplace, and no
 * workspace-trust gate (personal scope). It is discovered in place (not copied to a cache),
 * so the binary we place in `bin/` is exactly what the hooks run.
 *
 * Env overrides (mainly for offline installs / the Phase-2b gate / CI):
 *   TOKELANG_LOCAL_BIN   path to a prebuilt binary to use instead of downloading
 *   TOKELANG_DOWNLOAD_BASE   release asset base URL (default: this repo's engine-v* release)
 *   TOKELANG_CLI_VERSION   engine release tag override (default: engine-v1.0.0)
 *   TOKELANG_INSTALL_DIR   install fully somewhere else (default: $CLAUDE_CONFIG_DIR or ~/.claude → /skills/tokelang)
 * Flags: --dry-run (resolve + report, touch nothing), --force (reinstall), --help.
 */

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const https = require('https');
const crypto = require('crypto');

const PKG_ROOT = path.resolve(__dirname, '..');
const PKG = require(path.join(PKG_ROOT, 'package.json'));

const ARGS = process.argv.slice(2);
const DRY_RUN = ARGS.includes('--dry-run');
const FORCE = ARGS.includes('--force');

if (ARGS.includes('--help') || ARGS.includes('-h')) {
  console.log(
    [
      'Tokelang Claude Code skill installer',
      '',
      'Usage: npx @tokelang-lite/claude-code-skill [--dry-run] [--force]',
      '',
      '  --dry-run   Show what would happen; change nothing.',
      '  --force     Reinstall even if already present.',
      '',
      'Installs to ~/.claude/skills/tokelang/ (override with TOKELANG_INSTALL_DIR).',
    ].join('\n'),
  );
  process.exit(0);
}

// ---- platform → release artifact name --------------------------------------------------
// Names MUST match the skill resolver (skill bin/tokelang-cli): tokelang-cli-<os>-<arch>,
// os = `uname -s` lowercased (windows shells normalized to "windows"), arch = `uname -m`.
function resolveArtifact() {
  const platform = os.platform(); // 'linux' | 'darwin' | 'win32'
  const arch = os.arch(); // 'x64' | 'arm64' | ...
  const table = {
    'linux:x64': 'tokelang-cli-linux-x86_64',
    'darwin:arm64': 'tokelang-cli-darwin-arm64',
    'darwin:x64': 'tokelang-cli-darwin-x86_64',
    'win32:x64': 'tokelang-cli-windows-x86_64.exe',
  };
  const artifact = table[`${platform}:${arch}`];
  if (!artifact) {
    fail(
      `unsupported platform ${platform}/${arch}.\n` +
        'Supported: linux x64, macOS arm64/x64, Windows x64.\n' +
        'Build from source instead: cargo build --release -p tokelang-cli',
    );
  }
  return artifact;
}

function fail(msg) {
  console.error(`\n✗ tokelang install failed: ${msg}\n`);
  process.exit(1);
}

// ---- download (follows GitHub's redirect to the asset storage host) --------------------
function download(url, redirectsLeft = 5) {
  return new Promise((resolve, reject) => {
    https
      .get(url, { headers: { 'User-Agent': 'tokelang-installer' } }, (res) => {
        const { statusCode, headers } = res;
        if (statusCode >= 300 && statusCode < 400 && headers.location) {
          if (redirectsLeft <= 0) return reject(new Error('too many redirects'));
          res.resume();
          return resolve(download(headers.location, redirectsLeft - 1));
        }
        if (statusCode !== 200) {
          res.resume();
          return reject(new Error(`HTTP ${statusCode} for ${url}`));
        }
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => resolve(Buffer.concat(chunks)));
      })
      .on('error', reject);
  });
}

function sha256(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

// ---- recursive copy with a per-file filter ---------------------------------------------
function copyTree(src, dest, filter) {
  const stat = fs.statSync(src);
  if (stat.isDirectory()) {
    fs.mkdirSync(dest, { recursive: true });
    for (const entry of fs.readdirSync(src)) {
      copyTree(path.join(src, entry), path.join(dest, entry), filter);
    }
  } else {
    if (filter && !filter(src)) return;
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(src, dest);
    // Preserve executability for the resolver + hook/statusline scripts.
    if (src.endsWith('.sh') || path.basename(src) === 'tokelang-cli') {
      fs.chmodSync(dest, 0o755);
    }
  }
}

async function main() {
  const artifact = resolveArtifact();
  // The engine binary is versioned independently of this npm package and is hosted on THIS
  // repo's own releases (the standalone tokelang-cli was retired 2026-06-29). Pinning to the
  // engine release tag means bumping the package version does not require re-publishing binaries.
  const tag = process.env.TOKELANG_CLI_VERSION || 'engine-v1.0.0';
  const base =
    process.env.TOKELANG_DOWNLOAD_BASE ||
    `https://github.com/tokelang/claude-code-skill/releases/download/${tag}`;

  const installDir =
    process.env.TOKELANG_INSTALL_DIR ||
    path.join(
      process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude'),
      'skills',
      'tokelang',
    );
  const binDir = path.join(installDir, 'bin');
  const binDest = path.join(binDir, artifact);

  console.log(`Tokelang Claude Code skill v${PKG.version}`);
  console.log(`  platform : ${os.platform()}/${os.arch()} → ${artifact}`);
  console.log(`  binary   : ${process.env.TOKELANG_LOCAL_BIN || `${base}/${artifact}`}`);
  console.log(`  install  : ${installDir}`);

  if (fs.existsSync(installDir) && !FORCE && !DRY_RUN) {
    console.log(
      `\n• Already installed at ${installDir}. Re-run with --force to reinstall.\n` +
        '  Restart Claude Code or run /reload-plugins if it is not active yet.',
    );
    return;
  }

  // 1) Obtain + verify the binary buffer before touching the install dir.
  let binBuf;
  if (process.env.TOKELANG_LOCAL_BIN) {
    binBuf = fs.readFileSync(process.env.TOKELANG_LOCAL_BIN);
    console.log(`  using local binary (${binBuf.length} bytes), skipping download/verify`);
  } else if (DRY_RUN) {
    console.log('\n[dry-run] would download + SHA-256 verify the binary, then assemble the plugin.');
    return;
  } else {
    console.log('\n→ downloading binary …');
    binBuf = await download(`${base}/${artifact}`).catch((e) =>
      fail(`could not download ${artifact}: ${e.message}\n(is the ${tag} release published?)`),
    );
    console.log('→ verifying checksum …');
    // The release publishes a single combined SHA256SUMS (one `<hash>  <name>` line per
    // artifact), not per-file .sha256 sidecars. Fetch it once and pick our artifact's line.
    const sumText = await download(`${base}/SHA256SUMS`).catch((e) =>
      fail(`could not download SHA256SUMS: ${e.message}`),
    );
    let expected = null;
    for (const line of sumText.toString('utf8').split('\n')) {
      const parts = line.trim().split(/\s+/);
      if (parts.length < 2) continue;
      const name = parts.slice(1).join(' ').replace(/^\*/, ''); // strip binary-mode '*' marker
      if (name === artifact) {
        expected = parts[0].toLowerCase();
        break;
      }
    }
    if (!expected) fail(`no SHA256SUMS entry for ${artifact}`);
    const actual = sha256(binBuf).toLowerCase();
    if (!/^[0-9a-f]{64}$/.test(expected) || expected !== actual) {
      fail(`checksum mismatch for ${artifact}\n  expected ${expected}\n  actual   ${actual}`);
    }
    console.log(`  ok (sha256 ${actual.slice(0, 16)}…)`);
  }

  if (DRY_RUN) {
    console.log('\n[dry-run] verified; would now write the plugin. Nothing changed.');
    return;
  }

  // 2) Fresh assemble: clear our own dir, copy the plugin tree (resolver yes, prebuilt
  //    platform binaries no — those are downloaded fresh), then drop in this host's binary.
  fs.rmSync(installDir, { recursive: true, force: true });
  fs.mkdirSync(installDir, { recursive: true });

  const PLUGIN_PARTS = [
    '.claude-plugin',
    'skills',
    'agents',      // tokelang-router + tokelang-worker (opt-in via /tokelang-router on)
    'hooks',
    'statusline',
    'settings.json',
    'README.md',
    'LICENSE',
  ];
  for (const part of PLUGIN_PARTS) {
    const src = path.join(PKG_ROOT, part);
    if (fs.existsSync(src)) copyTree(src, path.join(installDir, part));
  }
  // bin/: copy only the resolver wrapper, never any prebuilt tokelang-cli-<os>-<arch>.
  copyTree(path.join(PKG_ROOT, 'bin'), binDir, (f) => path.basename(f) === 'tokelang-cli');

  // 3) The downloaded/local binary for THIS host.
  fs.mkdirSync(binDir, { recursive: true });
  fs.writeFileSync(binDest, binBuf);
  fs.chmodSync(binDest, 0o755);

  console.log(`\n✓ Installed tokelang@skills-dir → ${installDir}`);
  console.log('\nNext:');
  console.log('  • Restart Claude Code (or run /reload-plugins) to activate it.');
  console.log('  • Verify:  claude plugin list   (look for tokelang@skills-dir)');
  console.log('  • Disable: claude plugin disable tokelang@skills-dir   (or delete the folder)');
  console.log('\nOptional — per-prompt INPUT compression (non-interactive):');
  console.log(`  alias claude='${binDest.replace(artifact, 'tokelang-cli')} wrap claude'`);
}

main().catch((e) => fail(e && e.message ? e.message : String(e)));
