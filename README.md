# Sokoban

## Build

### Windows

```sh
cargo build --release --manifest-path extension/Cargo.toml
mkdir -p build/windows
godot --headless --export-release "Windows" build/windows/sokoban.exe
```

### Linux

```sh
cargo build --release --manifest-path extension/Cargo.toml
mkdir -p build/linux
godot --headless --export-release "Linux" build/linux/sokoban
```

### Android

> [!WARNING]
> gdext support for Android is currently in its early stages. For more details, please refer to <https://github.com/godot-rust/gdext/issues/470>.

#### Linux

```sh
paru -S android-sdk android-ndk android-studio

rustup target add aarch64-linux-android
cargo install cargo-ndk
cd extension
env ANDROID_NDK_HOME=/opt/android-ndk cargo ndk --target arm64-v8a build --release --features godot/experimental-threads
cd ..
mkdir -p build/android
```

The **Debug** build package can be exported directly via the following command:

```sh
godot --headless --export-debug "Android" build/android/sokoban.apk
```

Exporting a Release build requires generating a Keystore for signing. Install and use `archlinux-java` to specify a default JDK, then use the `keytool` command to generate the Keystore.

The following steps are also required to export the **Release** package:

```sh
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 10000 -deststoretype pkcs12
```

Open the **Export** interface and set the **Release** path under **Keystore** (`keystore/release`) to the location of the generated file. Then, configure the following two properties:

- **Release User** (`keystore/release_user`): `androiddebugkey`.
- **Release Password** (`keystore/release_password`): `android`.

Then, the Release build package can be exported via the following command:

```sh
godot --headless --export-release "Android" build/android/sokoban.apk
```

#### Windows

On Windows, the SDK and NDK can be installed via Android Studio.

```sh
scoop install android-studio
```

In Android Studio, navigate to `SDK Manager | Languages & Frameworks | Android SDK | SDK Tools` to select and install the following components:

- `Android SDK Build-Tools`
- `NDK (Side by side)`

```ps1
$env:ANDROID_NDK_HOME="C:\Users\sms\AppData\Local\Android\Sdk\ndk"
cd extension
cargo ndk --target arm64-v8a build --release --features godot/experimental-threads
cd ..
```

### WASM

> [!WARNING]
> gdext support for WASM is currently in its early stages. For more details, please refer to <https://godot-rust.github.io/book/toolchain/export-web.html>.

#### Windows

> [!WARNING]
> Do not use the `--manifest-path` parameter here, as it will cause `.cargo/config.toml` to be ignored.

```ps1
scoop install emscripten
emsdk install latest

rustup toolchain install nightly
rustup component add rust-src --toolchain nightly
rustup target add wasm32-unknown-emscripten --toolchain nightly

emsdk activate latest
cd extension
cargo +nightly build -Zbuild-std --target wasm32-unknown-emscripten --release --features godot/experimental-wasm,godot/lazy-function-tables
cd ..
mkdir -p build/wasm
godot --headless --export-release "Web" build/wasm/index.html
```

## Assets

| Name                        | Author    | License   |
| --------------------------- | --------- | --------- |
| [Prototype Kit]             | [Kenney]  | [CC0]     |
| [Game Icons]                | [Kenney]  | [CC0]     |
| [Game Icons (Expansion)]    | [Kenney]  | [CC0]     |
| [Input Prompts]             | [Kenney]  | [CC0]     |
| [Background Elements Redux] | [Kenney]  | [CC0]     |
| [RPG Audio]                 | [Kenney]  | [CC0]     |
| [Sarasa Gothic]             | [Belleve] | [OFL-1.1] |

[Prototype Kit]: https://kenney.nl/assets/prototype-kit
[Game Icons]: https://kenney.nl/assets/game-icons
[Game Icons (Expansion)]: https://kenney.nl/assets/game-icons-expansion
[Input Prompts]: https://kenney.nl/assets/input-prompts
[Background Elements Redux]: https://kenney.nl/assets/background-elements-redux
[RPG Audio]: https://kenney.nl/assets/rpg-audio
[Sarasa Gothic]: https://github.com/be5invis/Sarasa-Gothic
[Kenney]: https://kenney.nl/
[Belleve]: https://github.com/be5invis
[CC0]: https://creativecommons.org/publicdomain/zero/1.0/legalcode
[OFL-1.1]: https://openfontlicense.org/open-font-license-official-text/
