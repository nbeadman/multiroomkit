---
layout: page.njk
title: The project
heading: MultiroomKit
eyebrow: The project
category: Foundations
permalink: /about/index.html
description: MultiroomKit is a planned open-source Swift toolkit for Sonos control, Apple platform experiences, a command-line tool, and an MCP server.
summary: An open-source Swift project for exploring better ways to control music around the house.
---
## Why build it?

I have a Sonos system, and I want to understand what a well-designed toolkit for controlling it could look like. The project is also a chance to make my engineering process visible: architecture, debugging, tests, documentation, and the judgment behind each choice.

I’m a senior iOS developer. I want this work to show how I build and reason about software, including how I use AI assistance.

## The intended shape

- **A Swift library** that models rooms, speakers, groups, and playback.
- **Native Apple experiences** built on shared capabilities, with platform constraints made explicit.
- **A command-line tool** for repeatable, scriptable control.
- **An MCP server** that gives AI agents access to those same capabilities.

These are project goals. Read-only prototypes and a first experimental library slice exist; supported products and real Apple-platform networking coverage remain ahead.

## The first questions

How much can be done reliably on the local network? Where does the supported Sonos cloud API make sense? What can be shared across Apple platforms, and what needs a different approach? The first implementation should answer a small, testable part of those questions.

## Working with AI

I use AI assistants for research and implementation. I prompt them to draft all diary prose except Nick's Notes, then review the result. Each entry identifies the assistant used and records the evidence behind the decisions. Claims about reliability and platform support should follow testing.

## Where things stand

The diary and read-only status prototypes are in place. A first experimental Swift library now separates speaker topology from group playback, with synthetic integration tests and opt-in live checks. It is not yet a stable SDK, and simulator compilation does not establish real iOS or tvOS networking support.

[Read the first entry →](/journal/starting-with-the-record/)
