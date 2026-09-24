# MultiroomKit developer diary

A small, static engineering journal for the MultiroomKit project. Built with Eleventy and published by GitHub Pages. The first entry is an editable starter drafted with Codex from the project discussion; review its wording before the initial public push.

## Local preview

Requires Node.js 22 or later and pnpm 11.25.0 (the version in `package.json`).

```sh
pnpm install --frozen-lockfile
pnpm dev
```

Open http://localhost:8088. The rendered output is `_site/` and is not committed.

## Publish on GitHub Pages

The intended repository is `nbeadman/multiroomkit` and the intended public site is https://nbeadman.github.io/multiroomkit/. A project repository keeps your account-level portfolio URL free for later.

1. Create a public repository named `multiroomkit` under `nbeadman`.
2. Push these source files to its `main` branch.
3. In **Settings → Pages → Build and deployment**, select **GitHub Actions**.
4. If the first deployment ran before Pages was enabled, rerun **Build and publish diary** from the Actions tab.

The workflow derives the site prefix and GitHub link from the actual repository. A repository named `multiroomkit` publishes at `https://YOUR-USERNAME.github.io/multiroomkit/`. An account-level `YOUR-USERNAME.github.io` repository is also supported. Custom domains require updating the URL configuration in the workflow.

Pull requests build and check the site without publishing. Pushes to `main` deploy automatically after those checks pass. No personal access token is stored in the repository.

## Write an entry

Copy `templates/entry.md` to `site/journal/a-short-descriptive-slug.md`. Set the title, description, date, entry number, and category. Keep `draft: true` while writing; drafts do not produce public pages or journal listings. Set `draft: false` when ready to publish.

Use filenames without date prefixes: the filename becomes the permalink, while the front matter controls chronology. Keep entry numbers unique. The homepage automatically lists entries newest first.

Capture objectives, selected AI assistance, outcomes, verification, decisions, and lessons. Avoid presenting untested plans as shipped features. Summarize technical evidence before publishing; do not commit access tokens, household identifiers, serial numbers, or private device/network details.

## Check a build

```sh
pnpm build
pnpm check
```

To verify project-site URLs locally:

```sh
SITE_PATH_PREFIX=/multiroomkit/ pnpm build
SITE_PATH_PREFIX=/multiroomkit/ pnpm check
```

The build check validates local links/assets, base paths, page titles, headings, and template rendering. It runs in the deployment workflow.

## Main files

- `site/index.njk`: journal homepage and current-stage note.
- `site/about.njk`: project brief.
- `site/journal/`: Markdown entries.
- `site/_includes/`: shared page and entry layouts.
- `site/assets/style.css`: responsive styling.
- `site/_data/site.js`: site identity and deployment metadata.
- `.github/workflows/pages.yml`: build, checks, and publication.

The site has no analytics, cookies, external fonts, or client-side JavaScript. Content is readable without scripting. MultiroomKit is an independent project and is not affiliated with Sonos.
