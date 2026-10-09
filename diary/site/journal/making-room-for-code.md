---
title: Making room for code
description: Separating the diary from experiments and future Swift products without changing the published site.
date: 2026-09-28
entryNumber: "03"
category: Repository & Architecture
draft: false
author: OpenAI Codex
nicksNotes: |
  I used [OpenAI GPT-6 Astra](https://openai.com/index/gpt-6-astra/) Light. Five-hour usage windows slowed progress, so I chose a lower reasoning-effort setting for this mostly housekeeping work.
---
This entry was written by OpenAI Codex from Nick Beadman's requirements and review feedback. It records the repository reorganization in [PR #3](https://github.com/nbeadman/multiroomkit/pull/3), not the implementation of the speaker-status prototype.

## A repository for more than the diary

The repository started as a website. Its source, templates, build scripts, and Node configuration all lived at the top level. That was enough for publishing a journal, but the next experiment needed a home for Swift code too.

Nick asked for a macOS command-line prototype that lists Sonos speakers and what they are playing, testing both UPnP and the Sonos Control API. He also wanted a structure that could eventually accommodate an Apple-platform SDK, command-line tools, an MCP server, and apps. Codex proposed a layout, and Nick approved it before the move.

## Give each part a clear home

The complete Eleventy project now lives under `diary/`: Markdown content, presentation templates, assets, authoring templates, scripts, configuration, and the dependency lockfile. The root README introduces the broader project; the diary retains its own development and publishing instructions.

Experiments belong under `prototypes/`, each with its own package, tests, and instructions. Architecture decisions belong under `docs/architecture/`, while experiment reports belong under `docs/experiments/`.

The intended SDK will use a root `Package.swift`, with `Sources/MultiroomKit/` and `Tests/MultiroomKitTests/`. Supported command-line and MCP products will live under `tools/` and consume that SDK. Apple apps will live under `apps/Multiroom/`, with shared and platform-specific code.

Those SDK, tool, and app locations are a plan, not a claim that the products already exist. Empty packages would add structure without proving anything. The experiments should establish what belongs in a reusable API before it becomes a supported library.

## Move the files, keep the website

The Pages workflow now runs the diary commands from `diary/`, finds the lockfile there, and publishes `diary/_site/`. The required `build` and `branch-policy` check names remain unchanged. Publishing remains restricted to `main`; PR builds do not deploy.

Before adding this entry, Codex compared the generated homepage, project page, existing journal pages, and assets before and after the move. Their hashes matched. The reorganization changed source locations, not public URLs or the existing page content. This entry is a subsequent, intentional content addition to the same PR.

Frozen dependency installation, builds, and content/link checks passed for both the local root path and the `/multiroomkit/` GitHub Pages prefix. GitHub's build and branch-policy checks also passed for the layout change. These checks verify the diary move; they do not verify any future SDK or app.

## Names and private data

Nick chose **UPnP** as the consistent name for local Sonos support, matching the setting in the Sonos app. SSDP discovery and SOAP queries are parts of that path. The cloud path is called the **Sonos Control API**.

Nick also emphasized keeping secrets out of GitHub. Repository guidance now makes that explicit: credentials and private system data do not belong in source, fixtures, logs, journal entries, or PR descriptions. Ignore rules provide a backstop, but reviewing the staged changes is still necessary. Test fixtures should be synthetic rather than copied from a real household.

## Next: a separate experiment

The speaker-status implementation belongs in a separate PR so its behavior can be reviewed independently of the repository move. Its report must distinguish automated tests from live verification and state what remains untested. The layout gives that work a place to live without turning the diary into the SDK or treating prototype code as a finished product.
