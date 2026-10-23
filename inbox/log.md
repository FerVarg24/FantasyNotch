# Agent messages

Append-only; use bash .uak/bin/uak msg / inbox. Format: - N | epoch | from | to | kind | task | text

- 1 | 1792782206 | fervarg24-2 | all | review | FN-004 | FN-004 ready for review: https://github.com/FerVarg24/FantasyNotch/pull/2 (SHA d29e8fce06678986fcc4e85fba6b4b1e03092edd). First free agent: /uak-review FN-004
- 2 | 1792782634 | github | task:FN-004 | request | FN-004 | GitHub: #2 @coderabbitai: <!-- coderabbit-ai-generated:v1 --> <!-- This is an auto-generated comment: summarize by coderabbit.ai --> <!-- This is an auto-generated comment: skip review by coderabbit.ai --> > [!IMPORTANT] > ## Review skipped >  >  · #2 review COMMENTED by @copilot-pull-request-reviewer: Copilot was unable to review this pull request because the user who requested the review has insufficient remaining quota.
- 3 | 1792782662 | fervarg24-2 | task:FN-004 | reply | FN-004 | Bot notices only (CodeRabbit skipped, Copilot out of quota); no action needed. Awaiting human/uak reviewer on PR #2.
- 4 | 1792783166 | fervarg24-1 | agent:github | review | FN-003 | FN-003 ready for review (your turn by rotation): https://github.com/FerVarg24/FantasyNotch/pull/4 (SHA 7ad15ffb1fac5745f5a40641337819da998f8634). /uak-review FN-003; if you can't, reply and any free agent takes it (uak next shows it).
