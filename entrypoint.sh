#!/bin/sh -l

set -e

# Arguments from action.yml
MUST_HAVE_SUBJECT_LINE=$1
SUBJECT_LINE_CAPITALISED=$2
NO_PERIOD_AT_END_OF_SUBJECT_LINE=$3
FIRST_WORD_IN_SUBJECT_LINE_IS_IMPERATIVE_VERB=$4
BODY_MUST_HAVE_BLANK_LINE=$5
BODY_MUST_BE_WRAPPED_AT_72_CHARACTERS=$6

# Initialize a variable to track the last echo command
last_echo_was_newline=false

function log() {
  # Check if the text is empty (implies wanting a newline)
  if [[ -z "$1" ]]; then
    # Check if the last echo was not a newline
    if [[ "$last_echo_was_newline" == false ]]; then
      echo ""
      last_echo_was_newline=true
    fi
  else
    echo "$1"
    last_echo_was_newline=false
  fi
}


# Default to master if no argument is provided
BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)' | sed 's/origin\///' | head -n 1)
BASE_BRANCH=${BASE_BRANCH:-main}

# Default to HEAD if no argument is provided
CURRENT_BRANCH=HEAD

log "Checking commit messages between:"
log "- base branch: $BASE_BRANCH"
log "- current branch: $CURRENT_BRANCH"
log ""

# Check if branches exist locally
if ! git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
    log "❌ Failed: Base branch $BASE_BRANCH does not exist"
    exit 1
fi

if ! git rev-parse --verify "$CURRENT_BRANCH" >/dev/null 2>&1; then
    log "❌ Failed: Current branch $CURRENT_BRANCH does not exist"
    exit 1
fi

# Fetch all commits from the current branch compared to the base branch
COMMITS=()
if ! GIT_COMMITS=$(git log "$BASE_BRANCH".."$CURRENT_BRANCH" --no-merges --format="%H"); then
  log "❌ Failed fetching commits between $BASE_BRANCH and $CURRENT_BRANCH. Please check the branches."
  exit 1
fi

while read -r commit; do
  COMMITS+=("$commit")
done <<< "$GIT_COMMITS"

# Check if there are no commits
if [ ${#COMMITS[@]} -eq 0 ]; then
  log "No commits to check against the base branch"
  exit 0
fi

# Iterate over each commit
for COMMIT in "${COMMITS[@]}"; do
  log "Checking commit: $COMMIT"
  log ""

  # Extract the commit message
  COMMIT_MESSAGE=$(git show -s --pretty=format:%B "$COMMIT" --)

  log "Commit message:"
  log "$COMMIT_MESSAGE"
  log ""

  # Extract the subject line and body
  SUBJECT_LINE=$(echo "$COMMIT_MESSAGE" | head -n 1)
  BODY=$(echo "$COMMIT_MESSAGE" | sed '1,/^\s*$/d')

  log "Extracted parts from the commit message"
  log "Subject line: $SUBJECT_LINE"

  if [[ -z "${BODY// /}" ]]; then
    log ""
    log "ℹ No body present in the commit message"
  else
    log "Body:"
    log "$BODY"
  fi

  log ""

  log "Beginning checks"

  log ""

  log "Check 1: Subject line presence"
  if [[ -z "$SUBJECT_LINE" ]]; then
    log "❌ Failed: Commit subject line must be present."
    exit 1
  else
    log "✅ Passed"
    log ""
  fi

  log "Check 2: Subject line character limit"
  if [[ ${#SUBJECT_LINE} -gt 72 ]]; then
    log "❌ Failed: Subject line must not exceed 72 characters."
    exit 1
  else
    log "✅ Passed"
    log ""
  fi

  log "Check 3: JIRA ticket number format"
  if ! [[ "$SUBJECT_LINE" =~ ^[A-Z]+-[0-9]+: ]]; then
    log "❌ Failed: Subject must start with a JIRA ticket number followed by a colon."
    exit 1
  else
    log "✅ Passed"
    log ""
  fi

  log "Check 4: Capitalisation"
  SUBJECT_TEXT=$(echo "$SUBJECT_LINE" | sed -E 's/^[A-Z]+-[0-9]+: //')
  FIRST_WORD=$(echo "$SUBJECT_TEXT" | awk '{print $1}')
  if [[ "$FIRST_WORD" != "$(echo "$FIRST_WORD" | awk '{print toupper(substr($0,1,1))tolower(substr($0,2))}')" ]]; then
    log "❌ Failed: The first word of the subject text must begin with a capital letter."
    exit 1
  else
    log "✅ Passed"
    log ""
  fi

  log "Check 5: No punctuation at the end of the subject line"
  if [[ "$SUBJECT_LINE" =~ [.,\;\!]$ ]]; then
    log "❌ Failed: Subject line must not end with punctuation."
    exit 1
  else
    log "✅ Passed"
    log ""
  fi

  log "Check 6: Imperative mood (Basic check by rejecting common non-imperative patterns)"
  if [[ "$FIRST_WORD" =~ (ed|ing)$ ]]; then
    log "❌ Failed: Use imperative mood in the subject line. e.g., 'Add' instead of 'Added'."
    exit 1
  else
    log "✅ Passed"
    log ""
  fi

  if [[ -n "$BODY" ]]; then
    log "Check 8: Ensure body is separated by a blank line"
    FIRST_BODY_LINE=$(echo "$COMMIT_MESSAGE" | sed -n '2p')
    if [[ -n "$FIRST_BODY_LINE" ]]; then
      log "❌ Failed: Body must be separated from the subject by a blank line."
      exit 1
    else
      log "✅ Passed"
      log ""
    fi

    log "Check 9: Check each line of the body for length > 72"
    while IFS= read -r line; do
      if [[ ${#line} -gt 72 ]] && ! grep -q '^https://' <<<"$line" ; then
        log "❌ Failed: No line in the body should exceed 72 characters."
        exit 1
      else
        log "✅ Passed"
      fi
      log ""
    done <<< "$BODY"
  fi
done

log ""
log "✅ Commit message meets the required standards."

time=$(date)
echo "time=$time" >> $GITHUB_OUTPUT