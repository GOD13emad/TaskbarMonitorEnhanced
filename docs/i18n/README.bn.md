# Taskbar Monitor Enhanced — বাংলা

Taskbar Monitor Enhanced Windows taskbar-এর জন্য একটি হালকা system monitor। এটি গুরুত্বপূর্ণ hardware ও network information সরাসরি taskbar-এ দেখায়, তাই আলাদা monitoring window খোলা রাখতে হয় না।

## বর্তমান সংস্করণ

**1.2.0 (source candidate; public release: v1.1.3)**

## প্রধান বৈশিষ্ট্য

- CPU, RAM, disk, GPU ও VRAM monitoring
- আলাদা download ও upload speed
- CPU Package ও GPU temperature
- 28টি built-in theme
- live graph ও sparkline
- taskbar-এর left, center বা right placement
- adjustable width ও safe placement
- right-click menu
- Explorer restart-এর পর automatic recovery
- main app administrator privilege ছাড়াই চলে
- protected hardware-sensor component
- Windows startup support
- Desktop ও Start Menu shortcut

## Installation

Releases থেকে `TaskbarMonitorEnhanced_Setup_<version>.exe` ডাউনলোড করে চালান। Hardware sensor component install করার জন্য Windows administrator অনুমতি চাইতে পারে, তবে মূল app non-elevated থাকে।

1.2.0 candidate লোকাল build, determinism, visual proof এবং installed runtime health পরীক্ষায় PASS করেছে; exact GitHub head CI ও publication gate PASS না করা পর্যন্ত এটি public release নয়।

## Developer

**Dr. Ali-Akbar Emadeddin** — GitHub: `GOD13emad`

প্রকল্পটি `leandrosa81/taskbar-monitor` থেকে উদ্ভূত এবং upstream attribution ও GPL license সংরক্ষণ করে।

AI-assisted tools code drafting, refactoring, diagnostics, testing এবং documentation-এ সহায়ক হিসেবে ব্যবহৃত হয়েছে। Engineering requirements, architecture, hardware validation, acceptance testing এবং release responsibility মানুষের নিয়ন্ত্রণে ছিল।

## License

GNU GPL v3.0

[Main README](../../README.md)
