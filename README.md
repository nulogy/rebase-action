# Nulogy Rebase GitHub Action

Fork of the `cirrus-actions/rebase` repo for rebasing a PR

# Example Usage

Add the following setup code to `.github/workflows/rebase.yml`.

```yml
name: Rebase

on:
  issue_comment:
    types: [created]

jobs:
  rebase:
    name: Rebase
    if: github.event.issue.pull_request != '' && contains(github.event.comment.body, '/rebase')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v1.2.0
      - uses: nulogy/rebase-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  always_job:
    name: Aways run job
    runs-on: ubuntu-latest
    steps:
      - name: Always run
        run: echo "This job is used to prevent the workflow to fail when all other jobs are skipped."
```

Then on a PR, type `/rebase` into the comments section.

This will fail if the HEAD branch is not rebaseable on top of the BASE branch of the PR.
