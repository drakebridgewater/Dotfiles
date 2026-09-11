---
mode: "agent"
description: "Fetch last week's activity via the work-report MCP server and format it as a detailed professional weekly report"
tools:
  - mcp_work-report_generate_report
---

Call `generate_report` with `days: 7` to fetch GitLab MR and Jira activity for the past week. Then compose the full weekly report using the format and depth described below. Do not summarize lightly — this report is used for yearly review and team communication.

---

## Format

### Executive Summary callout

```
> [!Note] Executive Summary
> - **Bold sentence per major effort** — one sentence on what shipped or what advanced, with MR/ticket refs inline. 3–6 bullets max.
```

Follow with a brief **Availability Note** if there were interruptions (PTO, on-call, etc.) that explain lower-than-normal commit volume. Omit if the week was normal.

```
> [!QUOTE] Active Items
> - Things needing my attention or waiting on others.
```

---

### Detailed Contributions

Number each section. Use this structure for every MR or significant effort:

```
### N. Short Title (TICKET) — *Status: In Progress | Merged | Open*

#### MR: [!N](url) — (merged DATE | opened DATE | draft since DATE)

#### Problem: 
1–3 sentences explaining what was broken or why the work was needed. Be specific — mention failure modes, error messages, affected users/contexts.

#### What changed (N commits, N files):
A comprehensive, bulleted list of all specific code and configuration changes that shipped. This is the "what" and "how".
- Use nested bullets to group related changes under a parent item (e.g., a specific script that was refactored).
- Be specific: mention script names, function names, and the exact nature of the change.
- **Subsystem or theme** — what changed and why, in plain English. Name the files or functions.
- Continue for each logical cluster of changes.
- Note test coverage changes explicitly.

| File | +Added | −Removed |
|------|--------|----------|
| `path/to/file` | +N | −N |

> #Yearly-review — One sentence on why this matters beyond the week if it does. Cross-team reach, structural simplification, deletes-as-deliverables, etc. Omit if nothing notable.
```

Use `> #Yearly-review` blockquotes sparingly — only for genuinely significant work.

---

### Other Ticket Movement

End with a single table for tickets that moved status but don't warrant a full section:

```
| Ticket | Summary | Status | Movement |
|--------|---------|--------|----------|
| CDTOP-NNNN | Short description; note if blocked or waiting on someone. | Open | Old status → **New status** (date) |
```

---

## Style rules

- Write in past tense for merged/closed work, present tense for in-progress.
- Name specific files, functions, and error messages — do not paraphrase vaguely.
- "Deletion as the deliverable" — call out net-negative line counts as a positive signal.
- Do not embellish. Do not pad. Every sentence should contain a fact.
- If a commit message is ambiguous, describe the observable behavior it changes, not the message text.
