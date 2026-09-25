# Contributing and reviewing changes

All changes go through a pull request. `main` is the published branch, not a workspace for direct commits.

## Branch workflow

1. Fetch the latest `origin/main` and start a branch named `codex/<descriptive-title>`.
2. Use at least two lowercase, hyphen-separated words after `codex/`, for example `codex/pr-review-workflow`.
3. Make only the requested changes and run the checks below.
4. Push that branch and open a PR into `main` with a descriptive title, scope, and test results.
5. Discuss changes in the PR. Push follow-up commits to the same branch and respond with what changed and how it was checked.
6. Nick reviews the final diff and merges manually when ready. Agents must not merge or enable auto-merge without explicit permission.

Do not force-push over review history or bypass branch protection as a workaround. If a check blocks merging, fix or discuss the cause in the PR.

## Required validation

```sh
pnpm install --frozen-lockfile
pnpm build
pnpm check
SITE_PATH_PREFIX=/multiroomkit/ pnpm build
SITE_PATH_PREFIX=/multiroomkit/ pnpm check
```

The GitHub workflow checks branch naming (`branch-policy`) and builds and validates the diary (`build`). Both must pass before merging, and review conversations must be resolved. Keep these job names stable unless the required-check settings are updated too.

`main` protection also applies to administrators and blocks force pushes and deletion. A PR is required, but no second collaborator's approval is required: this is currently a solo-maintainer repository, and GitHub does not allow authors to approve their own PRs. Nick's manual merge is the final review decision. Repository protection is configured in GitHub settings; these instructions alone do not enforce it.

Only `main` may publish to GitHub Pages. PR builds and manual workflow runs on other branches cannot publish. Merging a PR triggers the normal Pages deployment.

## Working with Codex from PR comments

Use the official Codex GitHub integration. Connecting the GitHub plugin to a local chat is separate from enabling cloud work on PR comments.

### One-time account setup

1. Connect `nbeadman/multiroomkit` in [Codex cloud](https://chatgpt.com/codex).
2. Enable the repository in [Codex code review settings](https://chatgpt.com/codex/settings/code-review).
3. For editing tasks, ensure a cloud environment for this repository is available and can run the validation commands above. Use the Node and pnpm versions in `package.json`; do not add secrets for this public static site.

Automatic reviews are optional. This workflow uses explicit mentions so Nick chooses when to request another pass.

### Review and revision loop

- Request a review with `@codex review`.
- Request a focused change with `@codex address this feedback on the current PR branch, run the checks, and leave the PR open for my review` followed by the specific feedback.
- Ask a question with `@codex explain the tradeoff here without changing files`.

A plain comment without a mention is discussion, not a guaranteed trigger. A non-review mention starts a cloud task with the PR as context; it does not continue a particular desktop conversation. Include the relevant requirement in the comment. Codex can push a fix to the PR branch when its cloud environment and permissions allow it.

If there is no response, check the repository's Code review setting and cloud setup. If Codex cannot push, inspect its task and permissions rather than disabling protection on `main`.

No custom comment-execution workflow or OpenAI API key is needed for this integration. Do not post tokens or private device information in public PR comments. Follow-up edits and bot reviews still require human inspection.

See [the official Codex GitHub guide](https://learn.chatgpt.com/docs/third-party/github) for current setup and comment behavior.
