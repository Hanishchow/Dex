#!/usr/bin/env node
'use strict';

// Downloads the Dex desktop app from its GitHub release on first run, then
// launches it. Windows gets the portable zip, Linux the AppImage.
//   dex                 launch (downloads the app the first time)
//   dex --update        fetch the release this package version points at again
//   dex --uninstall     delete the downloaded app
//   dex --where         print where the app lives
//   dex --version | --help

const fs = require('fs');
const os = require('os');
const path = require('path');
const https = require('https');
const { spawn, spawnSync } = require('child_process');

const pkg = require('../package.json');
const REPO = 'Hanishchow/Dex';
const TAG = process.env.DEX_TAG || `dex-v${pkg.version}`;

function fail(message) {
  console.error(`dex: ${message}`);
  process.exit(1);
}

function platform() {
  if (process.arch !== 'x64') {
    fail(`only x64 builds exist (this machine is ${process.arch}). Download one from https://github.com/${REPO}/releases`);
  }
  if (process.platform === 'win32') return 'windows';
  if (process.platform === 'linux') return 'linux';
  return fail(`${process.platform} is not supported yet (Windows and Linux only).`);
}

function dataDir() {
  if (process.platform === 'win32') {
    return path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local'), 'Dex');
  }
  return path.join(process.env.XDG_DATA_HOME || path.join(os.homedir(), '.local', 'share'), 'dex');
}

const target = platform();
const installDir = path.join(dataDir(), TAG);
const asset = target === 'windows'
  ? `Dex-${TAG}-windows-x64.zip`
  : `Dex-${TAG}-linux-x86_64.AppImage`;
const url = `https://github.com/${REPO}/releases/download/${TAG}/${asset}`;
const launcher = target === 'windows'
  ? path.join(installDir, 'app', 'dex.exe')
  : path.join(installDir, asset);

function download(from, to, redirects = 0) {
  return new Promise((resolve, reject) => {
    if (redirects > 8) return reject(new Error('too many redirects'));
    https.get(from, { headers: { 'User-Agent': 'dex-player-npm' } }, (res) => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
        res.resume();
        return resolve(download(new URL(res.headers.location, from).toString(), to, redirects + 1));
      }
      if (res.statusCode !== 200) {
        res.resume();
        return reject(new Error(`download failed (HTTP ${res.statusCode}) for ${from}`));
      }
      const total = Number(res.headers['content-length']) || 0;
      let done = 0;
      let lastPrinted = 0;
      const file = fs.createWriteStream(to);
      res.on('data', (chunk) => {
        done += chunk.length;
        const now = Date.now();
        if (process.stderr.isTTY && now - lastPrinted > 250) {
          lastPrinted = now;
          const mb = (done / 1048576).toFixed(0);
          const pct = total ? ` (${Math.floor((done / total) * 100)}%)` : '';
          process.stderr.write(`\rdex: downloading ${mb} MB${pct}   `);
        }
      });
      res.pipe(file);
      file.on('finish', () => {
        if (process.stderr.isTTY) process.stderr.write('\n');
        file.close(() => resolve());
      });
      file.on('error', reject);
      res.on('error', reject);
    }).on('error', reject);
  });
}

function extractZip(zip, into) {
  fs.mkdirSync(into, { recursive: true });
  // Windows 10+ ships bsdtar, which reads zip files.
  const system32 = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32');
  let result = spawnSync(path.join(system32, 'tar.exe'), ['-xf', zip, '-C', into], { stdio: 'inherit' });
  if (result.status !== 0) {
    result = spawnSync('powershell', [
      '-NoProfile', '-Command',
      `Expand-Archive -LiteralPath '${zip}' -DestinationPath '${into}' -Force`,
    ], { stdio: 'inherit' });
  }
  if (result.status !== 0) fail('could not unzip the download.');
}

async function install() {
  fs.mkdirSync(installDir, { recursive: true });
  // Keep the real extension: PowerShell's Expand-Archive refuses a .part file.
  const tmp = path.join(installDir, target === 'windows' ? asset : `${asset}.part`);
  console.error(`dex: fetching ${asset} from GitHub (one time only)`);
  try {
    await download(url, tmp);
  } catch (err) {
    fs.rmSync(tmp, { force: true });
    fail(`${err.message}\n     Check that release ${TAG} exists: https://github.com/${REPO}/releases/tag/${TAG}`);
  }
  if (target === 'windows') {
    const appDir = path.join(installDir, 'app');
    fs.rmSync(appDir, { recursive: true, force: true });
    extractZip(tmp, appDir);
    fs.rmSync(tmp, { force: true });
  } else {
    fs.renameSync(tmp, launcher);
    fs.chmodSync(launcher, 0o755);
  }
  if (!fs.existsSync(launcher)) fail('the download did not contain the app.');
  console.error(`dex: installed to ${installDir}`);
}

function launch(extraArgs) {
  const args = [...extraArgs];
  // AppImages need FUSE; fall back to unpacking on the fly without it.
  if (target === 'linux' && (process.env.DEX_EXTRACT_AND_RUN === '1' || !fs.existsSync('/dev/fuse'))) {
    args.unshift('--appimage-extract-and-run');
  }
  const child = spawn(launcher, args, {
    cwd: path.dirname(launcher),
    detached: true,
    stdio: 'ignore',
    windowsHide: false,
  });
  child.on('error', (err) => fail(`could not start Dex: ${err.message}`));
  child.unref();
}

async function main() {
  const [flag, ...rest] = process.argv.slice(2);
  if (flag === '--version' || flag === '-v') {
    console.log(`dex-player ${pkg.version} (app release ${TAG})`);
    return;
  }
  if (flag === '--help' || flag === '-h') {
    console.log([
      'Usage: dex [options]',
      '',
      '  (no options)   launch Dex, downloading it the first time',
      '  --update       download the release again',
      '  --uninstall    delete the downloaded app',
      '  --where        print the install folder and download URL',
      '  --version      print versions',
      '',
      'Environment: DEX_TAG overrides the release tag; DEX_EXTRACT_AND_RUN=1 forces',
      'the AppImage to unpack itself (for systems without FUSE).',
    ].join('\n'));
    return;
  }
  if (flag === '--where') {
    console.log(`${installDir}\n${url}`);
    return;
  }
  if (flag === '--uninstall') {
    fs.rmSync(installDir, { recursive: true, force: true });
    console.log(`dex: removed ${installDir}`);
    return;
  }
  if (flag === '--update' || !fs.existsSync(launcher)) await install();
  launch(flag === '--update' ? rest : [flag, ...rest].filter(Boolean));
}

main().catch((err) => fail(err.message));
