# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.6 |
| **Installed at pin time** | 4.6.stable.official.89cea1439 (`C:/Godot/Godot_v4.6-stable_win64.exe`, not on PATH) — matches the pin |
| **Release Date** | January 26, 2026 (4.6); latest stable at pin time is 4.7.2 (August 2026), deliberately NOT used |
| **Project Pinned** | 2026-11-21 (re-pinned from 4.7 to 4.6 to match the installed editor and the godot-ai addon v3.2.5, which needs ≤4.6) |
| **Last Docs Verified** | 2026-10-21 (Windows driver default and Compositor, against Godot source); 2026-10-17 (release timeline and 4.7 changes); 2026-02-12 (4.4-4.6 content) |
| **LLM Knowledge Cutoff** | May 2025 |

## Knowledge Gap Warning

May 2025 is a floor for every model the studio runs on: a newer model may know more, but check this folder first.

The LLM's training data likely covers Godot up to ~4.3. Versions 4.5, 4.6
and 4.7 were released after the cutoff and introduced significant changes that
the model does NOT know about; 4.4 came out shortly before it and may be thinly
covered. Always cross-reference this directory before suggesting Godot API calls.

## Installed-Version Gap Warning

The warning above is one-directional — it covers the **model** knowing less than
this pin. The reverse gap is real and `/setup-engine` §3 creates it deliberately
("pin the newer one and upgrade later"): this reference can sit **ahead of the
installed editor**, and an agent citing it correctly then emits APIs that do not
compile locally. **Check `Installed at pin time` above before trusting a
version-qualified claim** — `NOT DETERMINED` means the gap is unknown, not absent.

## This project targets 4.6 — 4.7 content is NOT for this project

Sections in this folder labelled `4.7` or `4.6 → 4.7` describe the next version
and are kept for a later upgrade. **Do not use 4.7-only APIs here** (AreaLight3D,
VirtualJoystick, typed-return overrides, the Asset Store, etc.): they will not
compile in the installed 4.6 editor. Treat the `4.4`–`4.6` content as authoritative.

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 4.5 | Sep 2025 | HIGH | Accessibility (AccessKit), variadic args, @abstract, shader baker, SMAA |
| 4.6 | Jan 2026 | HIGH | Jolt default, glow rework, IK restored |
| 4.7 | Jun 2026 | HIGH | AreaLight3D, HDR output, Asset Store replaces the Asset Library, VirtualJoystick, Jolt soft-body and world-boundary changes, typed-return overrides |

## Before the Cutoff

4.4 (Mar 2025, Jolt option, FileAccess return types) predates the May 2025
cutoff; the Knowledge Gap Warning still applies to it.

Dates from https://github.com/godotengine/godot/releases, checked 2026-10-17:
4.4 Mar 3 2025, 4.5 Sep 15 2025, 4.6 Jan 26 2026, 4.7 Jun 18 2026, 4.7.2 Aug 18
2026. Migration guides and release notes: `breaking-changes.md` § Sources.
