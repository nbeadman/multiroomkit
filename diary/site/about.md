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

These are project goals. The implementation and platform support have not yet been established.

## The first questions

How much can be done reliably on the local network? Where does the supported Sonos cloud API make sense? What can be shared across Apple platforms, and what needs a different approach? The first implementation should answer a small, testable part of those questions.

## Working with AI

Codex will help with research, implementation, and review. The diary will identify that assistance and record the evidence behind the decisions. Claims about reliability and platform support should follow testing.

## Where things stand

Earlier conversations explored naming, existing projects, local UPnP control, and the official Sonos APIs. The diary is the first deliverable. Next comes a scoped experiment and a recorded decision about the first control path.

[Read the first entry →](/journal/starting-with-the-record/)
