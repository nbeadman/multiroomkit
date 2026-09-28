import assert from "node:assert/strict";
import { cp, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repository = process.cwd();
const cli = path.join(repository, "node_modules/@11ty/eleventy/cmd.cjs");

for (const prefix of ["/", "/multiroomkit/"]) {
  test(`Markdown content and links at ${prefix}`, async () => {
    const fixture = await mkdtemp(path.join(tmpdir(), "multiroomkit-content-"));
    try {
      await cp(path.join(repository, "site"), path.join(fixture, "site"), { recursive: true });
      await cp(path.join(repository, ".eleventy.js"), path.join(fixture, ".eleventy.js"));
      await symlink(path.join(repository, "node_modules"), path.join(fixture, "node_modules"), "dir");
      const homePath = path.join(fixture, "site/index.md");
      const source = await readFile(homePath, "utf8");
      await writeFile(homePath, source.replace(
        "The diary comes first.",
        "**Status fixture.** [Project details](/about/?from=card#details). The diary comes first.",
      ) + "\n**Homepage fixture.** [About](/about/) [External](https://example.com/path) [Anchor](#main)\n\n![Mark](/assets/favicon.svg)\n\nLiteral {{ untouched }}.\n");
      await writeFile(path.join(fixture, "site/journal/draft-fixture.md"), `---
title: Hidden draft fixture
date: 2099-01-01
entryNumber: "99"
draft: true
---
This must not be published.
`);
      // Deliberately reverse filename order relative to the entry numbers.
      for (const [slug, number] of [["a-earlier-fixture", "90"], ["z-later-fixture", "91"]]) {
        await writeFile(path.join(fixture, `site/journal/${slug}.md`), `---
title: Fixture ${number}
description: Sorting fixture
date: 2098-01-01
entryNumber: "${number}"
draft: false
---
Fixture entry.
`);
      }
      const result = spawnSync(process.execPath, [cli], {
        cwd: fixture,
        encoding: "utf8",
        env: { ...process.env, SITE_PATH_PREFIX: prefix, SITE_URL: "https://example.com", SITE_REPOSITORY: "https://github.com/nbeadman/multiroomkit" },
      });
      assert.equal(result.status, 0, result.stdout + result.stderr);
      const html = await readFile(path.join(fixture, "_site/index.html"), "utf8");
      assert.ok(html.includes("<strong>Homepage fixture.</strong>"));
      assert.ok(html.includes("<strong>Status fixture.</strong>"));
      assert.ok(html.includes("<strong>OpenAI Codex</strong>"));
      assert.ok(html.includes("with prompting by <strong>Nick Beadman</strong>"));
      assert.ok(html.includes("Human authored, not AI"));
      const notes = html.match(/<section class="principles human-notes wrap"[\s\S]*?<\/section>/)?.[0];
      assert.ok(notes, "Human-authored notes must have their own section");
      assert.ok(notes.includes('href="https://openai.com/codex/"'));
      assert.ok(notes.includes('href="https://www.linkedin.com/in/nbeadman/"'));
      assert.ok(!html.includes("That's what this journal is for."));
      assert.ok(html.includes(">A reviewable, Markdown-driven diary<"));
      assert.ok(!html.includes("/journal/content-without-the-layout/"));
      assert.ok(html.includes(`href="${prefix}about/?from=card#details"`));
      assert.ok(html.includes(`href="${prefix}about/"`));
      assert.ok(html.includes(`src="${prefix}assets/favicon.svg"`));
      assert.ok(html.includes('href="https://example.com/path"'));
      assert.ok(html.includes('href="#main"'));
      assert.ok(html.includes(`rel="canonical" href="https://example.com${prefix}"`));
      assert.ok(html.includes("Literal {{ untouched }}."), "Markdown must not run template expressions");
      assert.ok(!html.includes("Hidden draft fixture"));
      await assert.rejects(readFile(path.join(fixture, "_site/journal/draft-fixture/index.html")), { code: "ENOENT" });
      assert.ok(html.includes(">Fixture 91<") && html.includes(">Fixture 90<"));
      assert.ok(html.indexOf(">Fixture 91<") < html.indexOf(">Fixture 90<"));
      for (const [slug, phrase] of [
        ["starting-with-the-record", "A usage reset was required, but I deemed it necessary"],
        ["review-before-publishing", "this method is similar to how I work with other engineers"],
      ]) {
        const entry = await readFile(path.join(fixture, `_site/journal/${slug}/index.html`), "utf8");
        const panel = entry.match(/<section class="entry-human-notes"[\s\S]*?<\/section>/)?.[0];
        assert.ok(panel, `${slug}: missing human notes`);
        assert.ok(panel.includes(phrase));
        assert.ok(panel.includes("Human authored, not AI"));
        assert.ok(panel.includes("<code>main</code>"));
        assert.ok(entry.indexOf('<div class="prose">') < entry.indexOf(panel));
        assert.ok(entry.indexOf(panel) < entry.indexOf('<aside class="article-note">'));
      }
      const entryWithoutNotes = await readFile(path.join(fixture, "_site/journal/a-earlier-fixture/index.html"), "utf8");
      assert.ok(!entryWithoutNotes.includes('class="entry-human-notes"'));
      const about = await readFile(path.join(fixture, "_site/about/index.html"), "utf8");
      assert.ok(about.includes("<h2>Why build it?</h2>"));
      assert.ok(about.includes(`href="${prefix}journal/starting-with-the-record/"`));
      assert.ok(about.includes("<strong>A Swift library</strong>"));
      assert.ok(about.includes("Not affiliated with or endorsed by Sonos."));
      const notFound = await readFile(path.join(fixture, "_site/404.html"), "utf8");
      assert.match(notFound, /This page isn(?:'|&#39;)t here\./);
    } finally {
      await rm(fixture, { recursive: true, force: true });
    }
  });
}
