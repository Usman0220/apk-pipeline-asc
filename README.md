# APK Pipeline

Automated Android APK reverse engineering pipeline. Decompiles, analyzes, and reports on APKs using multiple engines and security analysis tools.

## Quick Start

```bash
# Interactive TUI (browse device packages, pull, analyze, browse URLs)
./apk-pipeline.sh tui

# Check available tools
./apk-pipeline.sh check

# Full pipeline on a single APK
./apk-pipeline.sh full app.apk

# Pull from device and analyze
./apk-pipeline.sh pull --pkg com.example.app
./apk-pipeline.sh full output/com.example.app/apk_name.apk

# Batch process a directory of APKs
./apk-pipeline.sh batch ./apks/ --concurrency 4
```

## Pipeline Stages

```
APK Input
    │
    ├── 1. Decompile ──────────────────────────────────────
    │   ├── aapt          metadata, permissions, manifest
    │   ├── apktool       smali bytecode + resources
    │   ├── jadx          Java/Kotlin sources (deobfuscated)
    │   ├── dex2jar       JAR conversion
    │   ├── apk2url       URL/domain/IP extraction
    │   ├── native-strings URL extraction from compiled binaries (libapp.so Dart snapshot)
    │   ├── radare2       native .so string analysis
    │   └── exiftool      file metadata
    │
    ├── 2. Analyze ────────────────────────────────────────
    │   ├── YARA          pattern/rule matching (8 rules)
    │   ├── permissions   dangerous permission combos
    │   ├── secrets       API keys, passwords, tokens
    │   ├── crypto        weak/hardcoded crypto patterns
    │   ├── network       cleartext, trust managers
    │   ├── sensitive     clipboard, contacts, location
    │   ├── smali         root/debug/emu detection
    │   ├── native        .so imports and strings
    │   └── asc           Droid ASC cross-DEX ref search + single-class decompile
    │
    └── 3. Report ─────────────────────────────────────────
        └── REPORT.md    consolidated markdown report
```

## Commands

| Command | Description |
|---------|-------------|
| `tui` | Launch interactive TUI (fzf-based) |
| `pull` | Extract APKs from connected Android device via ADB |
| `decompile` | Decompile APK with all engines |
| `analyze` | Run deep static analysis on decompiled output |
| `report` | Generate markdown report |
| `quick` | Fast scan — URLs + secrets only (skips full analysis) |
| `asc` | Droid ASC — cross-DEX ref search + targeted class decompile |
| `full` | Run all stages (decompile + analyze + report) |
| `batch` | Process multiple APKs from directory or list |
| `check` | Show tool availability status |

### Interactive TUI

```bash
./apk-pipeline.sh tui
```

The TUI provides:
- **Package Browser** — list device packages (all/system/third-party), multi-select with fzf, live preview of `dumpsys package` info
- **Pull APKs** — download selected packages via ADB
- **Analyze APK** — pick decompile/analyze/report stages interactively
- **URL Browser** — browse extracted URLs, unique domains, IPs (with whois preview), search, export selections
- **Analysis Browser** — view permissions, secrets, YARA hits, crypto, network, smali patterns, native strings
- **Batch Mode** — run batch pipeline from directory or device

### Pull from device

```bash
./apk-pipeline.sh pull --list                    # List installed packages
./apk-pipeline.sh pull --pkg com.example.app     # Pull specific package
./apk-pipeline.sh pull --all                     # Pull all third-party APKs
./apk-pipeline.sh pull --split com.example.app   # Pull split APKs (AAB)
```

### Single APK

```bash
./apk-pipeline.sh decompile app.apk              # Decompile only
./apk-pipeline.sh analyze output/app/decompile   # Analyze only
./apk-pipeline.sh report output/app/decompile    # Report only
./apk-pipeline.sh full app.apk                   # Everything
```

### Batch mode

```bash
./apk-pipeline.sh batch ./apks/                  # Sequential
./apk-pipeline.sh batch ./apks/ 4                # 4 workers
echo -e "app1.apk\napp2.apk" > list.txt
./apk-pipeline.sh batch list.txt
```

## Output Structure

```
output/
└── <app_name>/
    └── decompile/
        ├── manifest.json          # Metadata
        ├── REPORT.md              # Final report
        ├── jadx_sources/          # Java/Kotlin code
        ├── apktool_smali/         # Smali + resources
        ├── dex2jar/               # JAR files
        ├── urls/                  # Extracted URLs, IPs, domains
        ├── native_libs/           # Extracted .so files
        ├── metadata/              # aapt, exiftool, ssdeep
        └── analysis/
            ├── yara_hits.txt
            ├── permissions.txt
            ├── secrets.txt
            ├── crypto.txt
            ├── network.txt
            ├── sensitive_data.txt
            ├── smali_patterns.txt
            └── native_strings.txt
```

## Tools Used

| Tool | Purpose |
|------|---------|
| [jadx](https://github.com/skylot/jadx) | Java/Kotlin decompiler with deobfuscation |
| [apktool](https://apktool.org/) | Smali disassembly + resource decoding |
| [apk2url](https://github.com/n0mi1k/apk2url) | URL/domain/IP extraction |
| [radare2](https://r2.re/) | Native binary analysis |
| [frida](https://frida.re/) | Dynamic instrumentation |
| [yara](https://virustotal.github.io/yara/) | Pattern matching rules |
| [androguard](https://github.com/androguard/androguard) | Python APK analysis |
| [Droid ASC](https://github.com/MG1937/ASC) | Zero-preprocessing cross-DEX ref search + targeted decompile |
| [aapt](https://developer.android.com/studio/command-line/aapt) | Android asset tool |
| [ssdeep](https://ssdeep-project.org/) | Fuzzy hashing |

## Requirements

- Linux (tested on Kali)
- Java 11+ (for jadx, apktool)
- Android SDK tools (aapt, adb, apksigner, zipalign)
- Python 3.10+ (androguard, frida-tools)

Run `setup.sh` to install everything: `sudo bash setup.sh`

## ASC Stage

[Droid ASC](https://github.com/MG1937/ASC) adds two O(1)-style primitives to the pipeline — lightning-fast cross-DEX reference search over strings/types/methods/fields, and extraction of a single class into a minimal in-memory DEX for instant decompilation. No full APK inflation, no heavy indexing:

```bash
# Ref search: who references this string/type/method/field anywhere in the APK
./apk-pipeline.sh asc refs app.apk string token -o refs.txt
./apk-pipeline.sh asc refs app.apk type com.poc.Main
./apk-pipeline.sh asc refs app.apk method onCreate --class com.poc.Main

# Targeted decompile of one class (fastest way to read a single class)
./apk-pipeline.sh asc class app.apk com.poc.Main -o Main.java

# Availability check
./apk-pipeline.sh check
```

Results land under `output/<app>/asc/` (`refs_*.txt` and `classes/*.java`) and are browsable from the TUI — **ASC Search** menu.

Install the engine (auto-detected from `~/ASC`, `<pipeline>/ASC`, or `/opt/ASC`; override with `ASC_DIR` in `config.env`):

```bash
git clone https://github.com/MG1937/ASC ~/ASC
pip install -r ~/ASC/requirements.txt
```

## Credits

Big thanks to **MG193.7 ([@MG1937](https://github.com/MG1937))** for creating **Droid ASC** (https://github.com/MG1937/ASC) — the R8-compiler-as-decompiler-primitive engine behind this pipeline's ASC stage. Its zero-preprocessing, millisecond cross-DEX search and targeted decompile are a great complement to the heavier jadx/apktool inflate-and-index stage. Grateful for the work 🙏
