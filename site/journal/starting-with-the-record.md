---
title: Starting with the record
description: Before the first speaker command, a place to document the work—and a few rules for what counts as progress.
date: 2026-09-24
entryNumber: "01"
category: Foundations
draft: false
nicksNotes: |
  I used GPT-6 Astra High. A usage reset was required, but I deemed it necessary because this was essentially the initial commit. Codex committed directly to `main`, which prompted the pull-request workflow changes.
---
The first deliverable for MultiroomKit is this diary.

The idea started with a Sonos system at home and a question: what would a useful, well-designed Swift toolkit for controlling it look like? That grew into a plan for Apple platform apps, a command-line tool, and an MCP server for AI agents.

Before taking on all of that, I want a place to keep the engineering record.

## What I'm setting out to build

MultiroomKit is intended to be an open-source project with a shared Swift core. It should make a small set of useful controls understandable and reliable, then expose them through different interfaces.

The project is also a professional calling card. That makes the reasoning, tests, and documentation part of the work from the beginning.

## What the research has surfaced

There are existing libraries and controller apps to learn from. One small macOS project, [MenuBarControllerSonos](https://github.com/whjvenyl/MenuBarControllerSonos), shows a local approach: discover speakers with SSDP, read their XML descriptions, and send SOAP control requests. Studying that source gave the protocol research a concrete starting point.

Sonos also publishes a [Control API](https://docs.sonos.com/docs/control). Deciding how that fits alongside local control needs its own experiment and architecture decision. I haven't committed the project to one transport yet.

Supporting Apple platforms is another question to test. A common Swift codebase is the aim; the network behavior and lifecycle constraints on each device still need investigation.

## How I'll use Codex

AI assistance is central to this project. I want to document which tasks I give Codex, what comes back, what I change, and what evidence supports the result.

A useful entry should answer:

1. What was I trying to accomplish?
2. What did Codex help with?
3. What worked, failed, or remained unclear?
4. How did I verify the outcome?
5. What decision did I make next?

For this first step, I asked Codex to set up a GitHub Pages site for documenting progress, and chose **MultiroomKit** as the title. Codex drafted the site and this initial entry from the project discussion. This is a starting record, to be revised as the work develops.

## The next experiment

The next milestone is deliberately small: choose an initial control path, connect to a real system, and verify one useful interaction. The results should determine the first library boundary and the next piece of work.

The wider library, CLI, MCP server, and apps are still ahead. This diary is where I'll record how we get there.
