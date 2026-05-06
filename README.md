<p align="center">
  <img src="docs/assets/hero.svg" alt="ZenTap hero" width="100%">
</p>

<p align="center">
  <a href="docs/README.zh-CN.md">中文</a>
  ·
  <a href="docs/README.en.md">English</a>
  ·
  <a href="LICENSE">MIT License</a>
</p>

# 指言 ZenTap

ZenTap is a small open-source macOS dictation tool: click a floating window to start speaking, click again to insert the recognized text.

指言是一款开源的 macOS 轻触式语音输入工具：点击悬浮窗开始说话，再点一次，把识别出的文字输入到当前光标处。

<p align="center">
  <img src="docs/assets/app-preview.svg" alt="ZenTap floating window preview" width="86%">
</p>

## Why

Most voice input tools are started by keyboard shortcuts. That is inconvenient for people who cannot easily use a keyboard, and it is also not ideal for anyone who wants a calmer, mouse-first writing flow.

ZenTap begins with accessibility, but it is not only for a specific group. It is for anyone who wants speech input to feel light, private, and human.

## Highlights

- Mouse-first: tap the floating window to start or stop dictation.
- Privacy-first: uses the macOS Speech framework with on-device recognition required.
- Offline-friendly: no network code, no upload path, no server.
- Bilingual: Chinese and English recognition modes.
- Minimal UI: standard mode plus Zen Mode, inspired by porcelain water and a bamboo leaf.
- Open source: built to be studied, improved, localized, and shared.

## Quick Start

1. Build and open the app:

   ```bash
   ./build.sh
   open ~/Desktop/ZenTap.app
   ```

2. Allow microphone and speech recognition permissions when macOS asks.
3. For automatic text insertion, enable ZenTap in:

   ```text
   System Settings -> Privacy & Security -> Accessibility
   ```

4. Put the cursor in any text field, tap ZenTap, speak, then tap again.

<p align="center">
  <img src="docs/assets/how-it-works.svg" alt="How ZenTap works" width="86%">
</p>

## More

- [中文介绍](docs/README.zh-CN.md)
- [English README](docs/README.en.md)
- [License](LICENSE)
