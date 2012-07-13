#!/bin/bash
target_branch=${1:-"integration"}
merge_branch=${2:-"merge/$target_branch"}

function status {
  echo "// $1"
}

function exit_if_local_mods {
  if [ ! -z "$(git status --porcelain)" ] ; then
    status "Local modifications detected. Cannot push."
    git status -s
    exit 1
  fi

  return 0
}

function merge_failed {
  status "Doh. Your merge has conflicts, but don\'t worry:"
  echo
  echo 1. Fix your merge conflicts
  echo 2. Commit them
  echo 3. Run mergeq again

  exit 1
}

function checkout_target_branch {
  status "Checking out $target_branch..."

  git fetch origin $target_branch
  git checkout -q FETCH_HEAD
  git reset --hard
  git clean -f
}

function cleanup {
  echo "
Returning to $branch..."
  git checkout -q $branch
  rm .merging
}

function try_to_merge {
  status "Merging $branch into $target_branch"

  git merge --no-ff $branch -m "Merge $branch into $target_branch" || merge_failed
}

function write_temp_file {
  status "Writing temp file..."
  echo "$branch;$merge_branch;$target_branch" > .merging
}

function start_merge {
  status "Starting merge..."
  set -e

  exit_if_local_mods

  branch=`git rev-parse --abbrev-ref HEAD`

  checkout_target_branch
  write_temp_file
  try_to_merge

  continue_merge
}

function push_failed {
  status "Your push failed, someone may have beat you. Try again?"
}

function exit_if_we_have_already_been_merged {
  set +e
  git fetch origin $target_branch
  git diff --quiet FETCH_HEAD
  if [ $? -eq 0 ]
  then
    echo "
**********************************************************

 This branch has already been merged into $target_branch

**********************************************************"
    cleanup
    exit 1
  fi
  set -e
}

function push_to_merge_branch {
  current=`git rev-parse HEAD`

  status "Merging into $merge_branch"
  git fetch origin $merge_branch
  git checkout -q FETCH_HEAD
  git merge --no-ff --no-commit $current
  git checkout $current -- .
  echo $current > .merge
  git add .
  git commit -m "Queuing merge: $branch into $target_branch"
  status "Queuing merge by pushing $merge_branch"
  git push origin HEAD:refs/heads/$merge_branch || push_failed
}

function continue_merge {
  exit_if_local_mods
  exit_if_we_have_already_been_merged
  push_to_merge_branch

  status "Done!"
  cleanup
}

if [ -f .merging ]
then
  IFS=';' read -ra branches < .merging
  branch=${branches[0]}
  merge_branch=${branches[1]}
  target_branch=${branches[2]}

  status "Continuing merge..."
  continue_merge
else
  start_merge
fi
