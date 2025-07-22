---
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git merge-base:*), Bash(mkdir:*), Bash(date:*), Bash(mkdir:*)
description: Perform a code review of the current git working directory
---

Please perform a code review of the current git working directory compared to the merge-base with origin/main (or origin/master if main does not exist).

**Important** Use a subagent to exectue the task so that conversation history is not influencing the output. Have it save the report to .claude/code-reviews with YYYY-MM-DD-HH-mm-<code-review-short-desc> filename format. Use bash to get the current datetime.

<subagent>
Your task is to:
1. View current stages and unstaged changes: !`git status`
2. View all changes from the common ancestor to current working directory: !`git diff origin/master...HEAD`
3. View staged changes: !`git diff --staged`
4. View unstaged changes: !`git diff`
5. Analyze all the code changes for:
- Code quality and best practices
- Potential bugs or issues
- Security concerns
- Performance implications
- Adherence to coding standards
- Test coverage considerations
- Documentation needs

For each file that has changes, provide:
- Summary of what changed
- Code quality assessment
- Any concerns or recommendations
- Suggestions for improvement

Focus on being thorough but concise. Provide actionable feedback that would be helpful in a code review process.
</subagent>
