# Agent handoff

## Start here

Read [README.md](README.md) for supported behavior, compatibility, and determinism
requirements; [BUILDING.md](BUILDING.md) for dependency and Docker commands; and
[DEBUGGING.md](DEBUGGING.md) before investigating crashes or simulation changes.
Inspect `git status --short` and the current diff before editing. Do not assume
previous session artifacts, Docker images, or commits exist on a fresh checkout.

Cv4MiniEngine is an x64 Civilization IV: Beyond the Sword engine reimplementation
with a terminal UI and a headless executable. It requires separately installed,
user-owned game assets. BUG Mod is recommended but optional. Missing BUG patch
messages alone do not indicate a startup failure.

## Collaboration and privacy

- Use subagents for substantial investigations and implementation work when an
  independent task can be delegated. Delegate crash reproduction, backtrace
  analysis, or independent review while the primary agent coordinates and verifies.
- Assign clear tasks and file ownership to avoid overlapping edits. Share findings
  and incorporate the subagents' evidence into the final result.
- Keep documentation, handoffs, examples, and shared diagnostics portable. Use
  repository-relative paths, shell variables, or relative placeholders. Never
  record absolute paths or machine-specific identifiers, including usernames,
  local installation locations, account metadata, hostnames, or local process IDs.
- Do not copy private launcher metadata, proprietary game assets, credentials,
  user configuration, saves, logs, or core dumps into tracked files. Sanitize
  diagnostics before quoting or sharing them.
- Preserve user changes, configuration, saves, and crash evidence. Reproduce
  failures using an isolated copy of runtime data whenever possible.

## Project map

| Location | Responsibility |
| --- | --- |
| `CmdCiv4/` | Terminal application, screens, file dialogs, audio, startup |
| `Cv4HeadlessEngine/` | Headless application and simulation runner |
| `Cv4CommonEngineLib/` | Engine services, VFS, XML/cache handling, Python integration |
| `CvGameCoreDLL/` | Firaxis-derived game rules, AI, and optional enhancements |
| `CommonStuff/` | Shared utilities, algorithms, threading, and platform code |
| `HeckConsoleUI/`, `HeckTUIInputTest/` | Terminal UI library and input diagnostic |
| `PlayerBotGameBinding/`, `FortsneksTestBot/` | Bot interfaces and example player bot |
| `Data/` | Engine script overrides, XML, and map scripts installed with the engine |
| `FAStar/`, `external/` | Pinned source dependencies managed as Git submodules |
| `Dockerfile`, `docker/` | Isolated dependency image, build script, and game launcher |

## Build and dependencies

Keep toolchains and dependency installations in Docker. Do not install host-wide
packages or follow the host package-install examples in BUILDING.md for this
workflow. Docker was chosen for isolation, not because native builds inherently
conflict with system libraries.

From the repository root:

```sh
git submodule update --init --recursive
docker build -t cv4mini-build:local .
```

Then use the isolated Docker build invocation in BUILDING.md. The image's default
command runs `bash docker/build.sh` against the mounted checkout. The script
configures, builds, and installs; repeating it performs an incremental build.
Run the script inside Docker, where its dependency paths are valid.

- The base compiler image is pinned by digest. Source dependencies are pinned by
  submodule commits; distribution packages are installed only in the image.
  This does not promise bit-for-bit reproducibility of package repositories.
- Required source dependencies include SFML 3.1.0, Python 2.7.18, pybind11 2.9.2,
  pugixml 1.15, CLI11, S3TC decompression, stb, and FAStar. Keep Python/pybind11
  versions compatible: current pybind11 versions need not support Python 2.
- Python 2 is compiled in C11 mode with compatibility flags because the compiler's
  C23 default breaks its old C sources. The application uses C++26.
- Default output is Release, Regular DLL, engine, headless engine, input tester,
  and player bot. Native file dialogs, DLL enhancements, and AVX-512 are disabled.
  Common compiler flags still target x86-64-v3; check CPU compatibility if an
  otherwise unexplained illegal-instruction failure occurs.
- `BUILD_JOBS` controls application build parallelism; default is four. Additional
  CMake options can be passed to `bash docker/build.sh` inside Docker. See
  BUILDING.md for examples. Rebuild the image when image dependencies change.
- CMake explicitly finds and links `CLI11::CLI11`. Application headers support
  packaged CLI headers with a fallback to the older single-header distribution.
  Keep standard-library includes explicit rather than relying on transitive ones.

## Launch and persistent data

Run the launcher from the repository root, supplying a portable path variable:

```sh
CIV4_ROOT='relative/path/to/game-installation'
./docker/run.sh "$CIV4_ROOT"
# Optional engine arguments follow the installation directory:
./docker/run.sh "$CIV4_ROOT" --autostart
```

The supplied directory must contain `Beyond the Sword/Civ4BeyondSword.exe`.
Some Complete Edition packages nest this directory below the launcher's recorded
installation root. Check the layout locally; do not persist the discovered host
path. The directory picker must select the game mount root inside the container,
as described by `docker/run.sh --help`, rather than its Beyond the Sword subfolder.

The launcher mounts game assets read-only, runs as the current user, preserves
terminal input, and supplies persistent XDG locations. It works from other working
directories when invoked through its own path. Audio forwarding is not configured.
The installed executables target the container environment; do not assume they
can run directly on a host with different runtime libraries.

| Repository-relative location | Contents |
| --- | --- |
| `out/docker-build/` | CMake cache, compiled objects, and build-tree binaries |
| `out/docker-install/` | Installed binaries, libraries, launchers, and engine assets |
| `out/docker-install/log.txt` | Default application log; configuration can override it |
| `out/runtime/config/Beyond the Sword/` | Engine INI, profile, and user overrides |
| `out/runtime/data/Beyond the Sword/` | Saves and replays |
| `out/runtime/cache/Cv4MiniEngine/` | XML caches |
| `out/crash-investigation/` | Optional local crash backups and diagnostic captures |

`out/` is ignored by Git. Its contents are local artifacts, not required checkout
inputs. Do not delete runtime data or caches indiscriminately to diagnose a bug.
Default installed DLL directory is `CvGameCoreDLL_Regular` beneath the install
directory; other variants use different suffixes. `docker/run.sh` currently
selects Regular explicitly; it does not automatically select an enhanced DLL.

## Startup fix and regression checks

A Linux startup crash was traced to file enumeration using literal `xml/text`
against game directories named `XML/Text`. No text XML loaded, an empty text
cache was written, and the unimplemented XML-error dialog aborted.

- `Cv4CommonEngineLib/CvVFS.cpp` shares case-insensitive, per-mount path resolution
  between lookup and enumeration. Preserve mount precedence, original filename
  casing, and deterministic enumeration order when changing this code.
- `Cv4CommonEngineLib/MyCvDLLUtility.cpp` rejects text caches with nonpositive
  language counts or zero text entries so failed-start caches recover automatically.
  Preserve this validation when changing cache formats or startup behavior.

Verified before this handoff: the Docker build and install succeeded; executable
and bot runtime libraries resolved; Python 2 imports passed; both application
help commands worked. Actual GOG Complete Edition assets reached the main menu
with cold caches, warm caches, and a previously empty cache. The user subsequently
confirmed the game launched. This is startup validation, not a complete gameplay,
save compatibility, performance, determinism, enhanced-build, or host-audio test.
Recheck after relevant edits.

For appropriate changes, run shell syntax checks and an engine startup check:

```sh
bash -n docker/build.sh docker/run.sh
./docker/run.sh --help
./docker/run.sh "$CIV4_ROOT" --help
git diff --check
```

The last launcher command needs actual game assets even for engine help. Headless
startup reads its INI before parsing help, so use isolated, valid configuration
for headless checks. For VFS/cache changes, verify menu startup with both a cold
and warm cache and recovery from an empty cache; preserve existing data first.
Successful `--help` output alone does not validate asset loading.

## Debugging and behavior constraints

Start with the log and obtain a backtrace for crashes. Several engine interface
stubs intentionally abort, so SIGABRT may represent an unimplemented error-reporting
path rather than the underlying fault. Preserve the original executable and core
before rebuilding when needed to retain matching symbols.

The regular build image does not include GDB. Add debugging tools only in a
temporary derived image or container, never on the host. For assertions, use a
Debug build in an isolated build/install/runtime directory; switching build modes
can invalidate XML caches. See DEBUGGING.md for deeper checks.

Determinism is a correctness requirement. Regular mechanics should match vanilla
BTS with the documented script fixes. Enhanced code can change deterministic AI
tie-breaking, but nondeterministic AI is a bug. Parallel loops must not use
`CvRandom` directly. Simulation changes may require the game-state hash and
autoplay procedures in DEBUGGING.md; startup smoke checks are insufficient.

Keep commits focused: source dependency pins, compiler/CMake fixes, Docker workflow,
runtime fixes, and agent documentation can be reviewed separately. Check the index
before committing; submodule additions may already be staged. Do not commit,
publish, or alter user staging merely to prepare a handoff unless requested.
