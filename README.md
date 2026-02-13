# Sokoban

## DEBUG

`%APPDATA%\Godot\app_userdata\sokoban\settings.ini`

## Build

```sh
cargo build --release --manifest-path extension/Cargo.toml
mkdir -p build/windows
godot --headless --export-release "Windows" build/windows/sokoban.exe
```

## Assets

| Name                                   | Source                                                   | License   |
| -------------------------------------- | -------------------------------------------------------- | --------- |
| Prototype Kit                          | <https://kenney.nl/assets/prototype-kit>                 | [CC0]     |
| Universal Animation Library (Standard) | <https://quaternius.itch.io/universal-animation-library> | [CC0]     |
| Input Prompts                          | <https://kenney.nl/assets/input-prompts>                 | [CC0]     |
| Background Elements Redux              | <https://kenney.nl/assets/background-elements-redux>     | [CC0]     |
| RPG Audio                              | <https://kenney.nl/assets/rpg-audio>                     | [CC0]     |
| Sarasa Gothic                          | <https://github.com/be5invis/Sarasa-Gothic>              | [OFL-1.1] |

[CC0]: https://creativecommons.org/publicdomain/zero/1.0/legalcode
[OFL-1.1]: https://openfontlicense.org/open-font-license-official-text/
