---
title: Content without the layout
description: Moving the homepage and project writing into Markdown while keeping the design and journal assembly in templates.
date: 2026-09-25
entryNumber: "03"
category: Publishing
draft: false
---
The journal entries were already Markdown, but the homepage and About page were not. Their wording lived inside HTML templates. I asked why, and the answer was an implementation choice rather than a technical requirement.

For a site intended to document regular progress, that was the wrong editing boundary. Changing a paragraph or project status should not require working around layout markup.

## What belongs where

I asked Codex to separate content from presentation and to document both this change and [the preceding workflow change](/journal/review-before-publishing/).

The homepage now has a Markdown source file. Its main paragraph is ordinary Markdown; short fields such as the headline, status, and section labels live in front matter at the top. The project-card and closing-section prose use Markdown blocks in that same file. The About and not-found pages also have Markdown sources, and shared footer and diary-note prose live in Markdown fragments.

Templates still own the HTML structure, accessible navigation, decorative elements, and automatic journal list. CSS still owns appearance. The split does not mean every interface label needs its own content file; it means the writing can be edited without changing the layout.

## Two small details that matter

First, internal links need to work both locally and under GitHub Pages' `/multiroomkit/` prefix. Authors can now write a normal link such as `[The project](/about/)`. Eleventy's bundled HTML Base plugin handles the published prefix, rather than asking the author to insert template code into Markdown.

Second, both new entries share a date. The journal now uses entry number as the tie-breaker, so entry 03 appears before entry 02 rather than leaving their order dependent on file discovery.

The Markdown files are not preprocessed as templates. That keeps examples and prose separate from executable template expressions.

## Verification and limits

Codex checked builds at both URL prefixes, local links and assets, Markdown rendering, draft exclusion, and same-day ordering. The rendered homepage, project page, and entries were also inspected at desktop and mobile sizes. These checks concern the diary, not the future Swift library or Sonos integration.

The existing homepage and project wording was preserved; the substantive new writing is these two journal entries. Codex drafted the implementation and this account from our discussion. The change was prepared on a new `codex/` branch for PR review, rather than committed directly to `main`.

The result is a smaller task for the next writing session: open the relevant Markdown file, edit the content, and review the resulting page.
