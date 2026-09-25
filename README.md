# MultiroomKit developer diary

A small, static engineering journal for the MultiroomKit project. Built with Eleventy and published by GitHub Pages. The first entry is an editable starter drafted with Codex from the project discussion; review its wording before the initial public push.

## Local preview

Requires Node.js 22 or later and pnpm 11.25.0 (the version in `package.json`).

```sh
pnpm install --frozen-lockfile
pnpm dev
```

Open http://localhost:8088. The rendered output is `_site/` and is not committed.

## Contributing

Make changes on descriptive `codex/` branches and submit pull requests into `main`. Do not commit or push directly to `main`. Use PR comments for discussion and explicit Codex requests, then leave the final merge to Nick.

See [CONTRIBUTING.md](CONTRIBUTING.md) for branch rules, validation, and the Codex PR-comment setup. [AGENTS.md](AGENTS.md) contains the repository's agent instructions and review rules.

## Publish on GitHub Pages

The repository is `nbeadman/multiroomkit` and the public site is https://nbeadman.github.io/multiroomkit/. A project repository keeps your account-level portfolio URL free for later.

Publishing is already configured under **Settings → Pages → Build and deployment → GitHub Actions**. To publish an update, merge its reviewed PR into `main`. To retry a deployment, rerun **Build and publish diary** on `main` from the Actions tab.

The workflow derives the site prefix and GitHub link from the actual repository. A repository named `multiroomkit` publishes at `https://YOUR-USERNAME.github.io/multiroomkit/`. An account-level `YOUR-USERNAME.github.io` repository is also supported. Custom domains require updating the URL configuration in the workflow.

Pull requests build and check the site without publishing. Merges into `main` deploy automatically after those checks pass. Manual runs on other branches cannot publish. No personal access token is stored in the repository.

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

The build check validates local links/assets, base paths, page titles, headings, and template rendering. It also builds isolated fixtures at both URL prefixes to test Markdown fields, ordinary links, draft exclusion, and same-day entry ordering. It runs in the deployment workflow.

## Edit page content

Edit writing in Markdown, not in the layout templates:

- `site/index.md`: homepage introduction plus short front-matter fields for headings, project status, and section labels. The `project.body` and `principles.body` fields are Markdown blocks; preserve their YAML indentation.
- `site/about.md`: project-page metadata and ordinary Markdown prose.
- `site/404.md`: not-found page wording.
- `site/_includes/content/*.md`: shared footer and diary-note prose. These fragments have no front matter and do not become standalone pages.

Front matter is the YAML between the opening `---` lines. Short title/label fields are plain text. Headline lists control the designed line breaks; HTML and CSS stay in the templates. Write longer prose in the Markdown body or designated Markdown blocks. Use headings starting at `##` in page bodies because the layout supplies the page's `h1`.

Use ordinary site-root Markdown links such as `[The project](/about/)` and `[First entry](/journal/starting-with-the-record/)`. Do not add `/multiroomkit/` yourself: Eleventy's HTML Base plugin adds the deployment prefix to local links and assets. Full external URLs and fragment links are left alone. Markdown is not processed as Nunjucks, so it does not need template expressions or the `url` filter.

Journal entries sort newest date first, then highest entry number first for entries on the same day. Continue using unique, numeric entry numbers and `draft: true` until an entry is ready for review and publication.

## Main files

- `site/index.md`: journal homepage and current-stage content.
- `site/about.md`: project brief.
- `site/404.md`: not-found content.
- `site/journal/`: Markdown entries.
- `site/_includes/*.njk`: presentation layouts, including the automatic journal list.
- `site/_includes/content/`: shared Markdown fragments.
- `site/assets/style.css`: responsive styling.
- `site/_data/site.js`: site identity and deployment metadata.
- `.github/workflows/pages.yml`: build, checks, and publication.

The site has no analytics, cookies, external fonts, or client-side JavaScript. Content is readable without scripting. MultiroomKit is an independent project and is not affiliated with Sonos.
