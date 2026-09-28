import { rm } from "node:fs/promises";

// Only the ignored, generated build output. This prevents stale published pages
// surviving when an entry is deleted or changed back to a draft.
await rm(new URL("../_site/", import.meta.url), {
  recursive: true,
  force: true,
});
