---
title: A reviewable, Markdown-driven diary
description: Putting changes through pull requests, separating writing from presentation, and making authorship explicit.
date: 2026-09-25
entryNumber: "02"
category: Workflow & Publishing
draft: false
nicksNotes: |
  I used GPT-6 Astra High. The work needed to be split across two five-hour usage windows. I requested a PR review workflow so that PRs can be used to address feedback in the future. Normal AI prompting would be quicker, but this method is similar to how I work with other engineers. The lack of separation between content and presentation was an obvious omission in the previous system. I would have addressed it then, had Codex not committed directly to `main`.
---
This entry was written by OpenAI Codex from Nick Beadman's prompts and review feedback. It covers two related changes: establishing a branch-and-PR workflow, then separating the diary's content from its presentation.

## Review before publishing

Once the diary was live, Nick set a clear rule: no direct changes to `main`, descriptive `codex/` branches, and a pull request for each change set. The PR would be the place to discuss changes, record verification, and decide when to publish.

Nick also kept the proposed homepage and About-page Markdown conversion out of the initial workflow PR. The two changes were implemented separately, even though this journal entry now records them together.

Codex added repository instructions in `AGENTS.md`, a contribution guide, a PR template, and a branch-name check. The Pages workflow was tightened so a manual run on a non-main branch cannot publish the site.

The live protection settings on `main` require a PR, passing build and branch-policy checks on an up-to-date branch, and resolved review conversations. They apply to administrators too, and block force pushes and branch deletion.

There is deliberately no requirement for a second person's approval: Nick is currently the only collaborator, and an author cannot approve their own PR. His manual review and merge remain the final decision. Codex's instructions say to leave that decision to him.

The site build and link checks passed for both the root URL and the GitHub Pages project path. Codex also tested accepted and rejected branch names and checked the deployment guards. GitHub's required PR checks passed, with no site content included in the change.

Nick approved and merged [PR #1](https://github.com/nbeadman/multiroomkit/pull/1). The [post-merge build and deployment](https://github.com/nbeadman/multiroomkit/actions/runs/36166545435) succeeded.

## Comments need somewhere to run

Nick also wanted to direct Codex from PR comments. A working GitHub connector in a desktop chat is not the whole setup: comment-triggered tasks need a cloud environment for the repository.

The first attempt produced a useful, limited result. The Codex bot responded, but asked for a repository environment to be created. That confirmed the integration could respond; it did **not** prove that a full review-and-edit loop worked. The setup link in the bot's response also differed from the documentation link, which had redirected to the ChatGPT homepage.

That distinction belongs in the record. A bot reply is not the same as a successfully tested workflow.

## Content without the layout

The journal entries were already Markdown, but the homepage and About page still had their wording embedded in HTML templates. Nick questioned that choice: changing a paragraph or project status should not require editing layout markup.

The follow-up change gave the homepage its own Markdown source. Its introduction is ordinary Markdown; headings, status, and section labels live in front matter. The project-card and closing-section prose use Markdown blocks in the same file. The About and not-found pages also have Markdown sources, while shared footer and diary-note prose live in Markdown fragments.

Templates retain the HTML structure, accessible navigation, decorative elements, and automatic journal list. CSS retains the appearance. The aim is an editing boundary, not a separate content file for every interface label.

Ordinary internal Markdown links work at both the local root and GitHub Pages' `/multiroomkit/` prefix through Eleventy's bundled HTML Base plugin. Authors can write `[The project](/about/)` without inserting template code. Markdown itself is not preprocessed as a template.

The journal also uses entry number to order entries with the same date. That behavior remains covered by tests even after combining the two proposed entries into this one.

## Making authorship visible

During review, Nick asked for an explicit distinction between Codex-written content and his own writing. The homepage now identifies OpenAI Codex as the author, with prompting by Nick. Below “What belongs here,” a separate “Nick's Notes” section is labeled “Human authored, not AI.” Its Markdown body is Nick's supplied text, kept unchanged.

This entry uses that distinction too: Codex produced the implementation and the journal prose; Nick supplied the requirements, feedback, and merge decisions. The human-authored notes explain his tool choice in his own words.

## Verification and next step

The content change was prepared in [PR #2](https://github.com/nbeadman/multiroomkit/pull/2), on a `codex/` branch rather than directly on `main`. Builds and local-link checks passed at both URL prefixes. Isolated fixtures exercise Markdown rendering, internal and external links, draft exclusion, literal template expressions, and same-day ordering. The rendered pages were inspected at desktop and mobile sizes.

Those checks concern the diary, not the future Swift library or Sonos integration. The next writing session can start with the relevant Markdown file, followed by a review of the rendered page and PR before publication.
