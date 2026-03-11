# Sokoban

## Build

### Windows

```sh
cargo build --release --manifest-path extension/Cargo.toml
mkdir -p build/windows
godot --headless --export-release "Windows" build/windows/sokoban.exe
```

### Android

> [!WARNING]  
> [gdext](https://github.com/godot-rust/gdext) support for Android is currently in its early stages. For more details, please refer to <https://github.com/godot-rust/gdext/issues/470>.

```sh
paru -S android-sdk android-ndk android-studio

rustup target add aarch64-linux-android
cargo install cargo-ndk
env ANDROID_NDK_HOME=/opt/android-ndk cargo ndk -t arm64-v8a build --release --features godot/experimental-threads
mkdir -p build/android
```

The Debug build package can be exported directly via the following command:

```sh
godot --headless --export-debug "Android" build/android/sokoban.apk
```

Exporting a Release build requires generating a Keystore for signing. Install and use `archlinux-java` to specify a default JDK, then use the `keytool` command to generate the Keystore.

## Assets

| Name                                     | License   |
| ---------------------------------------- | --------- |
| [Prototype Kit]                          | [CC0]     |
| [Universal Animation Library (Standard)] | [CC0]     |
| [Input Prompts]                          | [CC0]     |
| [Background Elements Redux]              | [CC0]     |
| [RPG Audio]                              | [CC0]     |
| [Sarasa Gothic]                          | [OFL-1.1] |

[Prototype Kit]: https://kenney.nl/assets/prototype-kit
[Universal Animation Library (Standard)]: https://quaternius.itch.io/universal-animation-library
[Input Prompts]: https://kenney.nl/assets/input-prompts
[Background Elements Redux]: https://kenney.nl/assets/background-elements-redux
[RPG Audio]: https://kenney.nl/assets/rpg-audio
[Sarasa Gothic]: https://github.com/be5invis/Sarasa-Gothic
[CC0]: https://creativecommons.org/publicdomain/zero/1.0/legalcode
[OFL-1.1]: https://openfontlicense.org/open-font-license-official-text/
