# 20-20-20 KOReader Plugin (Fork by Ajay9634)

A feature-rich KOReader plugin designed to prevent digital eye strain by enforcing the **20-20-20 eye-rest rule** (every 20 minutes, look at something 20 feet away for 20 seconds).

It runs an unobtrusive background timer while you read or browse, displaying a fullscreen countdown screen when it is time to rest your eyes.

---

## 🌟 Key Features (0.1.2)

* **Configurable Timers & Safety Bounds**:
  * **First Start Delay**: Set an initial custom delay between **1 to 60 minutes** before the very first reminder triggers.
  * **Interval Timer**: Set recurring reminders between **1 to 180 minutes** (Default: `20 min`).
  * **Rest Countdown**: Set rest duration between **1 to 300 seconds** (Default: `20 sec`).
* **Flexible Operating Scopes**:
  * **Reading-Only Mode** *(Default: Disabled)*: Operates exclusively while a book or document is open. Closing the document pauses and clears the timer.
  * **Global KOReader Mode**: Extends timer coverage across the entire KOReader application.
* **Live "Running from" Status & Persistence**:
  * The Enable/Disable menu item dynamically tracks your state, showing `Disable timer (First delay: X min)` or `Disable timer (Running from HH:MM)`.
  * Automatically refreshes and updates the exact `Running from` timestamp across app restarts, document re-readiness, and device wake-ups on both Android and E-ink platforms.
* **Customizable Reverse Colour Rest Screen**:
  * Includes a dedicated toggle *(Default: Disabled)* to control whether the fullscreen rest overlay uses standard or inverted colors.
  * When checked, it displays a clean **black background with white text**. When unchecked, it displays a **white background with black text**, fully isolated from global KOReader night mode themes.
* **Session Rest Counter**:
  * Tracks how many rest breaks you have taken during your current reading session.
  * Displays the total in the main menu with a quick-tap option to reset the count to `0`.
* **Power & Sleep Resilience**:
  * Seamlessly hooks into KOReader power and e-ink suspend/resume events (`onSuspend`, `onResume`, `onUnsuspend`).
  * Recalculates and keeps timestamps accurate when the device wakes up from sleep.

---

## 📋 Prerequisites

* **KOReader** installed on your e-reader or device.
* USB or file manager access to your device's KOReader installation folder.

---

## 📲 Compatibility

Tested and verified on:
* **Kobo** (including Kobo Libra Colour)
* **Android** (KOReader for Android)
* **Kindle** / **PocketBook** (standard KOReader plugins directory layout)

---

## Installation

1. Download a ZIP of this repository.
2. Unzip it.
3. Make sure the unzipped folder is named `20-20-20.koplugin`.
4. Connect your e-reader to your computer.
5. Copy the `20-20-20.koplugin` folder into KOReader's `plugins` folder on your device.

   The final path should look like this:

   ```text
   koreader/plugins/20-20-20.koplugin/
   ```

6. Eject your e-reader safely.
7. Restart KOReader.

---

## Configuration

1. Open KOReader.
2. Open the main menu.
3. Go to the `Tools` tab.
4. Select `20-20-20 Timer`.
5. Use the menu to enable or disable the timer, change the interval, change the
   countdown duration, or show the rest screen immediately.

Default settings:

- Interval: `20` minutes
- Countdown: `20` seconds
- Timer: enabled on startup

## Usage

Once enabled, the plugin runs in the background. After the configured interval,
KOReader shows a fullscreen black rest screen with the countdown. When the
countdown finishes, the plugin closes the rest screen and starts the next
interval automatically.

## Keywords

KOReader, e-reader, plugin, 20-20-20, eye rest, reading break, e-ink, timer,
countdown, accessibility, KOReader plugin.
