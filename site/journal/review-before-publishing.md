---
title: Review before publishing
description: Moving changes onto branches and making pull requests the place for discussion, verification, and a deliberate merge.
date: 2026-09-25
entryNumber: "02"
category: Workflow
draft: false
---
The diary was live. Before changing it further, I wanted a clearer review process: no direct changes to `main`, descriptive `codex/` branches, and a pull request for each change set.

The point is not just to put a gate in front of publishing. The PR should be a useful engineering record: what changed, what was checked, what I questioned, and how the implementation responded.

## The boundary I set

I asked Codex to set up the GitHub workflow and open a PR. I also explicitly kept the proposed homepage and About-page Markdown conversion out of that change set. Process changes and content restructuring deserved separate reviews.

Codex added repository instructions in `AGENTS.md`, a contribution guide, a PR template, and a branch-name check. It also tightened the Pages workflow so a manual run on a non-main branch cannot publish the site.

The live protection settings on `main` require a PR, passing build and branch-policy checks on an up-to-date branch, and resolved review conversations. They apply to administrators too, and block force pushes and branch deletion.

There is deliberately no requirement for a second person's approval: I am currently the only collaborator, and an author cannot approve their own PR. My manual review and merge remain the final decision. Codex's instructions say to leave that decision to me.

## Comments need somewhere to run

I also wanted to direct Codex from PR comments. A working GitHub connector in a desktop chat is not the whole setup: comment-triggered tasks need a cloud environment for the repository.

The first attempt produced a useful, limited result. The Codex bot responded, but asked for a repository environment to be created. That confirmed the integration could respond; it did **not** prove that a full review-and-edit loop worked. The setup link in the bot's response also differed from the documentation link, which had redirected to the ChatGPT homepage.

That distinction belongs in the record. A bot reply is not the same as a successfully tested workflow.

## What was verified

Codex ran the site build and link checks for both the root URL and the GitHub Pages project path, tested accepted and rejected branch names, and checked the deployment guards. GitHub's required PR checks passed. No site content was included.

I approved and merged [PR #1](https://github.com/nbeadman/multiroomkit/pull/1). The [post-merge build and deployment](https://github.com/nbeadman/multiroomkit/actions/runs/36166545435) succeeded.

Codex drafted the workflow and this account of it. My contributions were the review requirement, the scope boundary, and the merge decision. The next change could now use that process: [separating the writing from its presentation](/journal/content-without-the-layout/).
