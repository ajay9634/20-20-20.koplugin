# Eye Rest Timer (20-20-20 Fork) - KOReader Plugin

An enhanced **fork** of the official 20-20-20 KOReader plugin. It provides a **zero-battery-drain, customizable Eye Rest & Break Timer** optimized for E-Ink e-readers (Kindle, Kobo) and Android devices.

---

## Fork Enhancements vs. Official

| Feature | Official Plugin | Enhanced Fork |
| :--- | :--- | :--- |
| **Battery Impact** | Continuous background timer loop (drains sleep mode battery). | **One-Time Manual Activation:** Zero automatic loops. |
| **Post-Rest Action** | Automatically restarts next timer. | **Choice Prompt:** *"Start Next Timer"* or *"Continue Reading (No Timer)"*. |
| **Night Mode** | Background inverts to white. | **Smart Theme Detection:** Guarantees dark overlay in Night Mode. |
| **UI Feedback** | Silent execution. | **Toast Notifications:** Clear popups when timers start/stop. |
| **Menu Options** | Basic toggle. | Dedicated **Start** and **Stop** menu buttons. |
| **Customization** | Fixed 20m / 20s. | **Fully Custom:** 1–360 min intervals & 1–1800 sec rest durations. |
| **Presets** | None. | **Quick Presets** (15m, 20m, 30m, 45m, 60m Pomodoro). |
| **E-Ink Refresh** | Basic overlay dismiss. | **Clean Refresh:** Eliminates ghosting on screen close. |

---

## Quick Start

1. Copy `twenty_twenty_twenty.koplugin` to your `koreader/plugins/` directory.
2. Restart KOReader.
3. Access via **Tools** > **Eye Rest Timer** inside any document.

---

## Configuration & Usage

* **Start one-time timer:** Begins a single reading countdown.
* **Stop one-time timer:** Cancels the active timer.
* **Set Interval / Rest Duration:** Custom spin pickers.
* **Quick Presets:** Instant schedule profiles.
* **Show rest screen now:** Triggers rest overlay immediately.

---

## Changelog

### v1.0.0 (Fork Release)
* **Refactored:** Converted to manual one-time activation to fix Kindle sleep battery drain.
* **Added:** Toast notifications (`InfoMessage`), post-rest completion dialog, and dedicated Start/Stop menu entries.
* **Added:** Full range custom interval/duration spinners and Quick Presets menu.
* **Fixed:** Night Mode color inversion, mobile font scaling, and E-Ink ghosting.

### v0.1.0 (Original Plugin)
* Initial release of the basic 20-20-20 timer.

---

## Credits & License

* Based on the original `20-20-20.koplugin` for KOReader.
* Refactored & enhanced with code assistance from **Gemini**.
* Released under the **AGPL-3.0 License**.
