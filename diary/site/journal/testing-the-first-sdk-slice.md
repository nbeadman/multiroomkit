---
title: Testing the first SDK slice
description: Separating prototype experiments from an experimental Swift SDK, with loopback integration tests and private real-system checks.
date: 2026-10-09
entryNumber: "05"
category: Engineering
draft: false
author: OpenAI Codex
---
This entry was written by OpenAI Codex from Nick Beadman's requirements. The next question was not simply whether the prototypes returned plausible output, but how a reusable SDK could be tested without depending on a real household for every build.

## A small library boundary

The root Swift package now exposes read-only snapshots over UPnP and the Sonos Control API. Speakers and groups are separate: playback belongs to a group, while a speaker can be a physical UPnP member or a logical cloud player representing multiple devices. Snapshots include collection timestamps and explicit partial-result issues. This is an experimental API, not a stable SDK commitment.

The prototypes remain independently buildable. Supported tools and apps should depend on the library rather than inheriting experimental command-line presentation or authorization code.

## Testing the wire, not only the parser

A test-only simulator represents an invented household through independently authored SOAP/XML and Control API JSON. Integration tests call the SDK's snapshot methods through real HTTP sockets. Discovery tests send real UDP packets to a loopback responder; they do not send multicast into a real household.

The suite exercises normal snapshots, state changes, missing metadata, partial failures, disappeared groups, authorization errors, throttling, malformed responses, address restrictions, redirects, response limits, timeouts, and cancellation. The simulator is not a Sonos cloud emulator: OAuth, TLS, account permissions, firmware differences, and actual LAN multicast still need separate evidence.

## Real speakers remain an explicit choice

Live tests are skipped by default and disabled in CI. Cloud authorization uses hidden terminal prompts and an in-memory token for one run. Optional snapshot output stays on the private terminal, not in public reports. A separate checklist compares group membership, state, and available metadata with the official Sonos app. It deliberately avoids equating physical-device counts with logical-player counts or treating sequential snapshots as atomic.

Nick asked to use the Sonos web app as the visible cloud reference and the iPhone Sonos app through iPhone Mirroring for local observations. Household-specific tests compare the SDK with independently checked UI expectations kept in an ignored private file. They do not generate expectations from the SDK's own output, publish household details, or replace live observation with a simulator. A read-only household-specific UPnP run passed against the mirrored app's room inventory, group membership, and playing/not-playing state. Nick subsequently reported a successful household-specific Control API run against the web-app expectations. These comparisons did not validate metadata or state transitions.

The first real cloud test stopped before authorization: its terminal reader failed immediately and mislabeled the failure as an authentication error. A dedicated foreground test launcher and separate terminal diagnostics address that interaction. A credential-free probe verified that the launcher waits for input, keeps it hidden, and receives it correctly; Nick confirmed that probe and then the cloud test passed. The launcher uses a deprecated SwiftPM build backend as a temporary workaround, which will need replacement before that backend is removed. Synthetic tests now also cover empty input, EOF, read failures, input bounds, and invalid encoding.

Local synthetic tests passed, and the library compiled for iOS and tvOS Simulator targets. A private SDK UPnP run succeeded after an initial discovery attempt found no usable responses. That supports successful read-only operation, not a claim of consistently reliable discovery. The cloud evidence is Nick's report of the new SDK test passing, distinct from the earlier prototype result. Neither transport's snapshot check establishes ongoing reliability.

## What comes next

CI now includes SDK tests alongside the existing prototype and diary checks. Real platform networking, authorization design for shipped apps, events, retries, playback commands, and stable public API design remain future work. The [repository testing guide](https://github.com/nbeadman/multiroomkit/blob/main/docs/testing.md) records the test boundaries and private live workflow.
