#!/bin/bash

set -e

# Workaround until new Actions support neutral strategy
# See how it was before: https://developer.github.com/actions/creating-github-actions/accessing-the-runtime-environment/#exit-codes-and-statuses
NEUTRAL_EXIT_CODE=0

# Skip if not a PR
echo "Checking if issue is a pull request..."
(jq -r ".issue.pull_request.url" "$GITHUB_EVENT_PATH") || exit $NEUTRAL_EXIT_CODE

if [[ "$(jq -r ".action" "$GITHUB_EVENT_PATH")" != "created" ]]; then
  echo "This is not a new comment event!"
  exit $NEUTRAL_EXIT_CODE
fi

PR_NUMBER=$(jq -r ".issue.number" "$GITHUB_EVENT_PATH")
echo "Collecting information about PR #$PR_NUMBER of $GITHUB_REPOSITORY..."

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "Set the GITHUB_TOKEN env variable."
  exit 1
fi

URI=https://api.github.com
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"

PR_URL="${URI}/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER"

pr_resp=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" "${PR_URL}")

BASE_REPO=$(echo "$pr_resp" | jq -r .base.repo.full_name)
BASE_BRANCH=$(echo "$pr_resp" | jq -r .base.ref)

if [[ "$(echo "$pr_resp" | jq -r .rebaseable)" != "true" ]]; then
  echo "GitHub doesn't think that the PR is rebaseable!"
  exit 1
fi

if [[ -z "$BASE_BRANCH" ]]; then
  echo "Cannot get base branch information for PR #$PR_NUMBER!"
  echo "API response: $pr_resp"
  exit 1
fi

HEAD_REPO=$(echo "$pr_resp" | jq -r .head.repo.full_name)
HEAD_BRANCH=$(echo "$pr_resp" | jq -r .head.ref)

echo "Base branch for PR #$PR_NUMBER is $BASE_BRANCH"

if [[ "$BASE_REPO" != "$HEAD_REPO" ]]; then
  echo "PRs from forks are not supported at the moment."
  exit 1
fi

# See: https://github.com/cirrus-actions/rebase/blob/master/entrypoint.sh#L86, https://github.com/actions/checkout/issues/766
git config --global --add safe.directory "$GITHUB_WORKSPACE"

git remote set-url origin https://x-access-token:$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY.git
git config --global user.email "action@github.com"
git config --global user.name "GitHub Action"

# Make sure branches are up-to-date
git fetch origin $BASE_BRANCH
git fetch origin $HEAD_BRANCH

# Rebase
git checkout -b $HEAD_BRANCH origin/$HEAD_BRANCH
git rebase origin/$BASE_BRANCH
git push --force-with-lease
HEAD_BRANCH_HEAD=$(git rev-parse HEAD)
echo "(Potentially) Rebased commit hash of HEAD is: $HEAD_BRANCH_HEAD"
