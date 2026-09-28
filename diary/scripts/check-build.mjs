import { readdir, readFile, stat } from "node:fs/promises";
import path from "node:path";
import assert from "node:assert/strict";

const root = path.resolve("_site");
const prefix = process.env.SITE_PATH_PREFIX || "/";
async function files(directory) {
  const items = await readdir(directory, { withFileTypes: true });
  return (
    await Promise.all(
      items.map((item) =>
        item.isDirectory()
          ? files(path.join(directory, item.name))
          : path.join(directory, item.name),
      ),
    )
  ).flat();
}
const pages = (await files(root)).filter((file) => file.endsWith(".html"));
assert(
  pages.length >= 4,
  "Expected home, about, journal entry, and 404 pages.",
);
for (const file of pages) {
  const html = await readFile(file, "utf8");
  assert.match(html, /<html lang="en">/, `${file}: missing language`);
  assert.match(html, /<title>[^<]+<\/title>/, `${file}: missing title`);
  assert.equal(
    (html.match(/<h1[ >]/g) || []).length,
    1,
    `${file}: expected one h1`,
  );
  const outsideCodeExamples = html.replace(/<code\b[^>]*>[\s\S]*?<\/code>/g, "");
  assert(!/\{\{|\{%/.test(outsideCodeExamples), `${file}: unrendered template`);
  for (const [, target] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (/^(?:https?:|mailto:|data:|#)/.test(target)) continue;
    const urlPath = target.split(/[?#]/)[0];
    assert(
      urlPath.startsWith(prefix),
      `${file}: link omits Pages base path: ${target}`,
    );
    let destination = path.resolve(
      root,
      decodeURIComponent(urlPath.slice(prefix.length)),
    );
    assert(
      destination === root || destination.startsWith(root + path.sep),
      "Link escapes output",
    );
    if (urlPath.endsWith("/"))
      destination = path.join(destination, "index.html");
    assert(
      (await stat(destination)).isFile(),
      `${file}: missing target ${target}`,
    );
  }
}
console.log(
  `Checked ${pages.length} pages: metadata, headings, templates, and all local links/assets (${prefix}).`,
);
