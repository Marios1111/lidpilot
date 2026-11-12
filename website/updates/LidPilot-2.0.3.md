<!-- sparkle-sign-warning:
IMPORTANT: This file was signed by Sparkle. Any modifications to this file requires updating signatures in appcasts that reference this file! This will involve re-running generate_appcast or sign_update.
-->
## 2.0.3

Released November 12, 2026 — build 21.

- Follow Lid dims only the built-in display to zero brightness while closed,
  then restores the previous brightness on reopening, Stop, expiry or safety
  cleanup. Automatic brightness, True Tone and external displays stay under
  their existing controls. A newer manual brightness change is respected.
- Saved brightness restoration survives app restart. Failed restoration remains
  visible as Recovery; wakefulness controls are still released independently.
- Includes the opt-in Prevent automatic lock choice in the menu bar and
  Settings, plus serialized helper status inspection to avoid Start/Stop races.
- Low Power Mode remains user-controlled. Zero brightness is not a claim that
  the panel is powered off. Built-in dimming uses a narrowly scoped private
  macOS API and may become unavailable on future macOS versions.

