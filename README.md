# iPinball 🎱

> A native iOS & macOS pinball machine in the style of the 90s tables: one neon playfield, six chained missions, multiball and a wizard mode.

[![Report Bug](https://img.shields.io/badge/Report-Bug-red)](https://github.com/VidiPT89/iPinball/issues)
[![Request Feature](https://img.shields.io/badge/Request-Feature-blue)](https://github.com/VidiPT89/iPinball/issues)

## ✨ Features

- ✅ A full 90s playfield — three pop bumpers, two slingshots, a five-target drop bank, four standup targets, two ramps, two orbits, a spinner, two saucers, a magnet and the P-I-N-B rollover lanes
- ✅ Three flippers on real pin joints, a pull-and-release plunger, and a nudge that tilts the table if you push your luck three times in two seconds
- ✅ Six chained missions — Warm-Up, Ramp Rush, Target Frenzy, Orbit Loop, Lock 3 and Jackpot Hunt — leading into the Final Shot wizard mode
- ✅ Three-ball multiball where everything scores double, lit jackpots and super jackpots
- ✅ Combo multiplier up to 8× on back-to-back ramps and orbits, player multiplier up to 5× from the lanes and the drop bank
- ✅ Ball save, extra balls, end-of-ball bonus, a stuck-ball watchdog and a ten-entry high score table with initials
- ✅ Neon table lighting, ball trails, shockwaves, screen shake, slow motion on a jackpot and floating score pops
- ✅ Fully synthesised audio and Core Haptics — no sound files, every effect generated at launch
- ✅ Bilingual PT-PT / English in-app language switch, independent of your device language
- ✅ Dark, Light and System appearance, with the iVidi.dev orange, burnt yellow and black
- ✅ Animated splash screen with developer credits, then straight into the main menu
- ✅ Touch controls on iPhone and iPad, full keyboard play on the Mac, and Reduce Motion support throughout
- ✅ Shared SwiftUI codebase running natively on both iPhone/iPad and Mac

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Physics & Rendering | SpriteKit |
| Audio | AVFoundation (synthesized SFX and music) |
| Haptics | Core Haptics |
| Project | XcodeGen |
| Min. iOS | 17.0 |
| Min. macOS | 14.0 |

## 🚀 Quick Start

### Prerequisites

- Xcode 15+ on macOS
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you change the file structure (`brew install xcodegen`)

### Installation

```bash
git clone https://github.com/VidiPT89/iPinball.git
cd iPinball
open iPinball.xcodeproj
```

Pick the `iPinball-iOS` or `iPinball-macOS` scheme and run (`⌘R`).

> The Xcode project is generated with XcodeGen from `project.yml`. If you add or move Swift files, regenerate it with `xcodegen generate`.

## 📖 Usage

1. Watch the splash screen, then choose **Play** from the main menu
2. Drag down anywhere and release to pull the plunger — the further you pull, the harder the ball is launched
3. Tap the left or right half of the screen for that flipper. The top third of the left half works the upper flipper
4. Flick a finger sideways while holding a flipper to nudge the table. Three nudges in two seconds cause a **TILT** and cost you the ball
5. Shoot a saucer to start a mission. Finish all six to unlock **Final Shot**, and clear **Lock 3** to start multiball
6. Chain ramps and orbits within four seconds to build the combo up to 8×, and complete the **P-I-N-B** lanes to raise the player multiplier up to 5×
7. On the Mac: `←` / `→` flippers, `↑` upper flipper, `Space` hold and release to launch, `N` / `M` nudge, `Esc` pause
8. Switch language, appearance, sound and controls any time from **Settings**

## 🧪 Testing

```bash
xcodebuild -project iPinball.xcodeproj -scheme iPinball-macOS -destination 'platform=macOS' test
xcodebuild -project iPinball.xcodeproj -scheme iPinball-iOS -destination 'generic/platform=iOS Simulator' build
xcodebuild -project iPinball.xcodeproj -scheme iPinball-macOS -destination 'platform=macOS' build
```

The rules engine, the table layout, the save format and the translations are covered by unit tests that never touch SpriteKit, so the whole suite runs in well under a second.

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

## 👨‍💻 Author

**David Arsénio Martins**

- 🌐 Website: [ividi.dev](https://ividi.dev)
- 🐙 GitHub: [@VidiPT89](https://github.com/VidiPT89)

## 🤝 Contributing

Contributions, issues and feature requests are welcome. Feel free to check the [issues page](https://github.com/VidiPT89/iPinball/issues).

---

<p align="center">Developed by <a href="https://ividi.dev">David Arsénio Martins</a></p>
<p align="center">⭐ If you like this project, give it a star!</p>
