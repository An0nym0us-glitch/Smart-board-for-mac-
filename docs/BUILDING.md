# Building and packaging ClassBoard

## Windows 10/11 (recommended target)

1. Install **Visual Studio 2022** (or 2019) with the *Desktop development with C++* workload.
2. Install **Qt 5.15.2** for `MSVC 2019 64-bit` with the Qt online installer. `aqtinstall`
   also works:
   ```powershell
   pip install aqtinstall
   aqt install-qt windows desktop 5.15.2 win64_msvc2019_64 -O C:\Qt
   ```
3. Install **CMake** (3.16 or newer) and, optionally, **Ninja**.
4. Open an *x64 Native Tools Command Prompt for VS* and run:
   ```bat
   cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=C:\Qt\5.15.2\msvc2019_64
   cmake --build build
   set QT_QPA_PLATFORM=offscreen
   ctest --test-dir build --output-on-failure
   ```
   With the Visual Studio generator, use `cmake -S . -B build -A x64 ...` and then
   `cmake --build build --config Release`.
5. Run `build\bin\ClassBoard.exe`. To run it outside the build tree, copy the Qt runtime next to
   it with `windeployqt`, or configure with `-DCLASSBOARD_DEPLOY_QT=ON`. With that option,
   every build runs `windeployqt` for you.

### Installer (Setup.exe)

CI builds `ClassBoard-Setup-<version>-x64.exe` on every push (artifact
**ClassBoard-Setup-windows-x64**). The version comes from `project(ClassBoard VERSION x.y.z)`
in `CMakeLists.txt`, the single place it is set: the app, `ClassBoard.exe`'s file properties
and the installer name all use it. To build the installer yourself:

1. Create the deployed application folder:
   ```bat
   cmake --install build --prefix C:\cb\ClassBoard
   windeployqt --no-translations --no-system-d3d-compiler --no-opengl-sw --no-compiler-runtime C:\cb\ClassBoard\bin\ClassBoard.exe
   ```
   Copy the Visual C++ runtime DLLs (`msvcp140*.dll`, `vcruntime140*.dll`, `concrt140.dll`
   from `%VCToolsRedistDir%x64\Microsoft.VC14x.CRT`) into `bin`, and optionally Poppler into
   `bin\poppler\bin` for PDF import.
2. Install [Inno Setup 6](https://jrsoftware.org/isinfo.php) and run
   ```bat
   iscc /DAppVersion=0.3.0 /DSourceDir=C:\cb\ClassBoard installer\ClassBoard.iss
   ```
   The installer is written to `installer\Output`.

The installer lets you install for all users (Program Files, needs administrator rights) or
only for yourself. It adds a Start menu entry, an optional desktop shortcut, opens
`.classboard` lessons with ClassBoard and has a normal uninstaller (Settings → Apps). Running
a newer installer updates an existing installation in place. Lessons, settings and autosave
data stay in the user's profile and are kept when ClassBoard is uninstalled.

The installer is not code-signed, so Windows SmartScreen may show "Windows protected your PC"
the first time: choose **More info → Run anyway**. Signing it needs a code-signing
certificate.

### Publishing a release

The release contains the Windows installer and both macOS disk images.

Releases are made by `.github/workflows/release.yml`. GitHub releases are immutable once
published (no assets can be added afterwards), so the workflow builds and tests, uploads the
installer to a **draft** release, checks the upload and only then publishes it. Never create
the release on github.com yourself: that publishes it (and its tag) before the installer
exists, and the installer can then never be attached.

1. Set the new version in `CMakeLists.txt` (`project(ClassBoard VERSION 0.3.0 ...)`), commit
   and push it. Use a version that has no release or tag yet.
   To describe the release, add `.github/release-notes/v0.3.0.md` in the same push: it is shown
   above the automatically generated list of changes.
2. Start the release, either
   * on github.com: **Actions → Release → Run workflow**, enter the same version (`0.3.0`),
     optionally a title (giving "ClassBoard v0.3.0 — <title>") and whether it is a
     pre-release; the workflow creates the tag `v0.3.0` when it publishes; or
   * from git: `git tag v0.3.0 && git push origin v0.3.0`.
3. The release appears with `ClassBoard-Setup-0.3.0-x64.exe`,
   `ClassBoard-0.3.0-macOS-arm64.dmg` and `ClassBoard-0.3.0-macOS-x86_64.dmg` once the run is
   green. You can
   edit its notes afterwards; its assets are fixed.

The workflow refuses, before building, a version that does not match `CMakeLists.txt`, a
version that already has a release (published or draft), and, for the manual trigger, a tag
that already exists. If a run fails after creating the draft, the draft is left unpublished:
delete it on the Releases page, fix the problem and run the release again.

### Portable ZIP (CPack)

```bat
cmake --build build --target package
```

CPack builds a portable ZIP (and, when NSIS is installed, a basic NSIS installer). The install
step runs `windeployqt` on the installed executable.

### Import requirements

Everything works offline; nothing is uploaded anywhere.

* **PDF import.** If Qt was built with the Qt PDF module (`Qt5Pdf`), CMake finds it and
  ClassBoard renders PDFs itself. Otherwise ClassBoard uses Poppler's `pdftoppm`, found
  on `PATH` or in a `poppler\bin` (or `poppler\Library\bin`) folder next to
  `ClassBoard.exe`. The Windows build produced by CI ships Poppler in `bin\poppler\bin`; for
  your own installer configure with `-DCLASSBOARD_POPPLER_DIR=<folder with pdftoppm.exe>`.
  Without a backend the PDF import buttons are disabled and explain why.
* **PowerPoint import (.ppt, .pptx).** Slides are converted to PDF by an installed office
  suite and then rendered like a PDF (so PDF import must be available too):
  * Microsoft PowerPoint (Windows) through its automation interface, or
  * LibreOffice (free, any platform) in headless mode — found on `PATH`, in
    `C:\Program Files\LibreOffice\program`, or in a `libreoffice\program` folder next to
    ClassBoard.
  Without either, the import explains what to install.

### Optional components
* **Recogniser plug-ins.** Offline handwriting-to-formula recognisers are Qt plug-ins placed in
  `plugins\recognizers` next to the executable. See `src/ai/Recognition.h`.

## macOS 10.13 and later (Apple silicon and Intel)

ClassBoard builds as a normal `ClassBoard.app` bundle and is packaged as a drag-to-Applications
disk image.

1. Install the **Xcode command line tools** (`xcode-select --install`) and
   [Homebrew](https://brew.sh).
2. Install Qt 5.15 and the build tools. Either
   * Homebrew (native on Apple silicon and Intel; the app then needs the macOS version
     Homebrew's libraries were built for, usually the one you build on):
     ```bash
     brew install qt@5 cmake ninja poppler
     cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
           -DCMAKE_PREFIX_PATH="$(brew --prefix qt@5)" \
           -DCMAKE_OSX_DEPLOYMENT_TARGET="$(sw_vers -productVersion | cut -d. -f1).0"
     ```
   * or the official Qt 5.15.2 build (Intel; also runs on Apple silicon through Rosetta 2,
     and on macOS 10.13 and later). Its *Qt WebEngine* package contains Qt PDF, which
     ClassBoard then uses for PDF import:
     ```bash
     pip3 install aqtinstall
     aqt install-qt mac desktop 5.15.2 clang_64 -m qtwebengine -O ~/Qt
     cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
           -DCMAKE_PREFIX_PATH=~/Qt/5.15.2/clang_64 -DCMAKE_OSX_ARCHITECTURES=x86_64
     ```
3. Build, test and run:
   ```bash
   cmake --build build
   QT_QPA_PLATFORM=offscreen ctest --test-dir build --output-on-failure
   open build/bin/ClassBoard.app
   ```
   The bundle in the build tree uses the Qt it was built against. Configure with
   `-DCLASSBOARD_DEPLOY_QT=ON` to copy Qt into it after every build (`macdeployqt`), so it
   also runs on Macs without Qt.

### Disk image (.dmg)

CI builds `ClassBoard-<version>-macOS-arm64.dmg` (Apple silicon, Homebrew Qt) and
`ClassBoard-<version>-macOS-x86_64.dmg` (Intel, Qt 5.15.2, macOS 10.13+) on every push
(artifacts **ClassBoard-macOS-arm64** and **ClassBoard-macOS-x86_64**). To build one yourself
from a configured build tree:

```bash
# Optional, when Qt PDF is not available: ship Poppler's pdftoppm inside the app.
cmake build -DCLASSBOARD_PDFTOPPM="$(brew --prefix)/bin/pdftoppm"
cmake --build build
scripts/macos/package.sh build
```

The script runs CPack, which installs `ClassBoard.app`, runs `macdeployqt` (Qt frameworks and
plug-ins, plus `pdftoppm` and its libraries when configured) and signs the bundle ad hoc. It
then mounts the image and checks that nothing in the app loads a library from outside the
bundle or macOS. The image contains `ClassBoard.app`, a link to `Applications` and the
documentation.

`ClassBoard.app` registers the `.classboard` lesson type, so lessons open with a double-click
in Finder, and offers **Open With → ClassBoard** for PDFs, presentations and images (they
are imported onto pages).

**Signing.** The app is signed ad hoc, not with an Apple Developer ID, so the first time it
is opened macOS says it "cannot check it for malicious software". Open it once from
**System Settings → Privacy & Security → Open Anyway** (on macOS 14 and earlier, Control-click
the app → **Open** also works), or remove the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/ClassBoard.app
```

With a Developer ID certificate in your keychain, configure with
`-DCLASSBOARD_CODESIGN_IDENTITY="Developer ID Application: <name> (<team>)"` to sign with the
hardened runtime, then notarise the image with `xcrun notarytool submit … --wait` and
`xcrun stapler staple`.

### Import on macOS

* **PDF:** built in (Qt PDF, Intel build) or with the `pdftoppm` shipped in the app (Apple
  silicon build). A source build without either finds Poppler from Homebrew or MacPorts
  (`brew install poppler`) even when ClassBoard is started from Finder.
* **PowerPoint (.ppt, .pptx):** needs LibreOffice in `/Applications` or `~/Applications`
  (`brew install --cask libreoffice`). Microsoft PowerPoint for Mac cannot be automated
  headlessly, so it is not used.

## Linux (development)

```bash
sudo apt install qtbase5-dev qtbase5-dev-tools libqt5svg5-dev cmake ninja-build
# optional, for PDF / PowerPoint import and their tests:
sudo apt install poppler-utils libreoffice-impress
cmake -S . -B build -G Ninja
cmake --build build
ctest --test-dir build --output-on-failure
```

## Continuous integration

`.github/workflows/build.yml` builds and tests on Windows (MSVC, Qt 5.15.2), macOS (Apple
silicon with Homebrew's Qt 5.15, Intel with Qt 5.15.2) and Linux on every push, with Poppler
and LibreOffice installed on Windows and Linux so the import tests run too. It uploads a
ready-to-run Windows folder (including Poppler), the Windows installer and both macOS disk
images as build artifacts. The macOS jobs also start the packaged app and upload a screenshot
of it.

## Diagnostics

* `ClassBoard --screenshot out.png` renders the window after start-up and exits (on macOS:
  `ClassBoard.app/Contents/MacOS/ClassBoard --screenshot out.png`).
* `ClassBoard --ui-scale 1.5` overrides the interface size.
* Set `CLASSBOARD_SCREENSHOTS=<dir>` when running `tst_ui`, `tst_tools_ui` or `tst_board_ui`
  to get a screenshot of every popover and tool.
