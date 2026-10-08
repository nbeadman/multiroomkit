---
title: Two routes to speaker status
description: A read-only UPnP experiment, a Sonos Control API prototype, and the OAuth callback that made a live cloud test possible.
date: 2026-10-08
entryNumber: "04"
category: Experiment
draft: false
---
This entry was written by OpenAI Codex from Nick Beadman's requirements and his report of a private live test. It covers the speaker-status prototype in [PR #4](https://github.com/nbeadman/multiroomkit/pull/4) and the OAuth callback delivered separately in [PR #6](https://github.com/nbeadman/multiroomkit/pull/6). Nick has not supplied human-authored notes for this entry.

## A small question before an SDK

Could a macOS command-line tool list the speakers in a Sonos system and show their playback status? Nick wanted both local-network and cloud approaches tested before deciding what should become a reusable Apple-platform SDK. He named the local path **UPnP**, matching the Sonos app's setting. Its discovery uses SSDP and its queries use SOAP. The cloud path uses the **Sonos Control API**.

Codex built two read-only executables in one experimental Swift package: `upnp-status` and `cloud-status`. They share table and JSON presentation, but keep their network implementations separate. Neither sends playback commands, and neither is yet a supported MultiroomKit product.

## UPnP on the local network

The UPnP prototype discovers a speaker, reads the system topology, and asks each group coordinator for playback state and metadata. It reports physical members, including bonded devices, while making their group relationship visible.

The first live multicast attempt returned nothing. Querying eligible local interfaces explicitly produced a successful private status snapshot. That points toward an interface-routing problem with the initial attempt, but does not identify a particular adapter as the cause. The tool now supports selecting an interface or using a known speaker address to bypass discovery. These are diagnostic options, not a claim that local discovery works on every network.

## A separate cloud route

The Sonos Control API requires a developer integration and user authorization. PR #6 provided a published HTTPS callback page that displays the returned authorization code and state for a one-session terminal flow. PR #4 then added hidden prompts for the integration key, client secret, state, and code. The tool checks the state, exchanges the code for an access token over HTTPS, and queries status without storing the credentials or tokens for later runs.

The callback page is suitable for this personal experiment, not production-grade OAuth hosting: GitHub Pages receives the initial callback URL containing the short-lived code. Nick entered the generated credentials only in his own terminal; they were not supplied to Codex or committed to the repository. The resulting status output remains private and is not committed.

On October 8, Nick reported that a real `cloud-status --json` run completed authorization and returned a Sonos Control API status snapshot. That establishes one successful end-to-end cloud run, based on his private observation. This public diary deliberately omits the household-derived output.

## What is proved, and what is next

Swift builds and synthetic tests exercise discovery, topology, parsing, grouping, authorization requests, state validation, and failure handling. The private live runs establish that each transport can return a snapshot on Nick's system. They do **not** establish that the two snapshots agree in every situation, or that the prototype handles every source, paused state, topology change, and macOS configuration.

The next useful check is a private comparison of UPnP, cloud, and the official Sonos app at the same time. Cloud rows represent logical players, while UPnP can expose physical members separately; a different row count alone is not a defect. The experiment will inform the SDK boundary only after those differences are understood.
