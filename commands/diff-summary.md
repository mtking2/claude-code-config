---
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git merge-base:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(date:*), Bash(mkdir:*)
description: Generate a summary of committed changes on current branch compared to base branch
---

Please generate a concise summary of all committed changes on the current branch compared to the base branch.

**Important** Use a subagent to execute the task so that conversation history is not influencing the output. Have it save the report to .claude/diff-summaries with YYYY-MM-DD-HH-mm-<branch-name> filename format. Use bash to get the current datetime and branch name.

<subagent>
Your task is to:
1. Determine the base branch name: !`git rev-parse --abbrev-ref --symbolic-full-name origin/HEAD`
2. Determine the current branch: !`git branch --show-current`
3. Find the merge base with the base branch: `git merge-base HEAD <base-branch>`
4. View all commits on current branch since merge base: `git log --oneline <merge-base>..HEAD`
5. View the full diff of committed changes: `git diff <merge-base>..HEAD`
6. Analyze the changes and create a summary that includes:
   - Total number of commits on the branch
   - List of modified files with statistics (additions/deletions)
   - High-level summary of what was changed (features added, bugs fixed, refactoring done)
   - Key architectural or design changes
   - Dependencies added or removed
   - Any breaking changes

Format the output as:
# Branch Diff Summary: [branch-name]

## Overview
- Commits: [number]
- Files changed: [number]
- Lines added: [+number]
- Lines deleted: [-number]

## Changes by Category
### Features
- [List new features]

### Bug Fixes
- [List bug fixes]

### Refactoring
- [List refactoring changes]

### Other Changes
- [List other changes]

## Modified Files
[List each file with brief description of changes]

Save this summary to the specified location.
</subagent>
