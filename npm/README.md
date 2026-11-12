# dex-player

One-command installer and launcher for **Dex**, a black-and-white gothic desktop
music player built on [Mornye](https://github.com/mornyeapp/Mornye) (LGPL-3.0).

```bash
npx dex-player          # run once, no install
# or
npm install -g dex-player
dex
```

The first run downloads the app (about 140-160 MB) from the GitHub release and
keeps it in your user folder; later runs start instantly.

| | |
|---|---|
| Windows 10/11 x64 | downloads the portable zip and runs `dex.exe` |
| Linux x64 | downloads the AppImage and runs it (adds `--appimage-extract-and-run` when FUSE is missing) |

Commands: `dex --update`, `dex --uninstall`, `dex --where`, `dex --help`.

Windows may warn about an unknown publisher because the app is not signed:
choose **More info**, then **Run anyway**.

Source and releases: https://github.com/Hanishchow/Dex
