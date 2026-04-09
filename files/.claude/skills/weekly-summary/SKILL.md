---
name: weekly-summary
description: Use when asked to summarize the week, update a weekly summary, or create a weekly activity canvas. Handles both creating a new canvas for the current week and updating an existing one with new activity.
---

# Weekly Summary

Creates or updates a Slack canvas summarizing the current week's activity. Currently sources from Slack; designed to be extended to additional sources (Linear, GitHub, etc.).

---

## Steps

### 1. Determine the week

Calculate the Monday of the current week (today's date is available in the system context). The canvas title format is: `Week of YYYY-MM-DD` where the date is that Monday.

### 2. Get the current user

Call `slack_read_user_profile` with no arguments to get the current user's ID and display name.

### 3. Check for an existing canvas

Search for an existing canvas for this week using `slack_search_public_and_private`:
```
query: "Week of YYYY-MM-DD" creator:@andrew.fitzpatrick
content_types: files
```
Use `type:canvases` if supported. If a canvas is found, note its `canvas_id` — you will **update** it. If not, you will **create** a new one.

If a canvas is found, read it with `slack_read_canvas` to extract the current **Todos** section. Preserve all existing todo items and their checked/unchecked state when updating.

**Also fetch the previous week's canvas:** Calculate the Monday of the previous week (current Monday minus 7 days), search for `"Week of YYYY-MM-DD"` (previous Monday's date) the same way, and read it with `slack_read_canvas`. Extract any **unchecked** (`- [ ]`) todo items from it — these are carry-overs. Ignore checked items.

### 4. Gather the week's messages

Search for all messages sent by the user this week using `slack_search_public_and_private`:
```
query: from:<@USER_ID> after:YYYY-MM-DD before:YYYY-MM-DD
sort: timestamp
```
Set `after` to Monday and `before` to tomorrow's date. Fetch multiple pages if needed (follow the cursor).

For any messages that are part of a thread with replies, use `slack_read_thread` to get full context.

### 5. Gather huddle notes

Search for huddle notes from this week using `slack_search_public_and_private`:
```
query: after:YYYY-MM-DD before:YYYY-MM-DD
content_types: files
```

Filter results for huddle-note canvases (look for files with names like "Huddle notes", "Meeting notes", or similar, attached to huddle threads). For each one found, read it with `slack_read_canvas` to extract the title, date, and any key discussion points or decisions. Note its canvas URL for linking.

If no dedicated search filter works for huddle notes, try:
```
query: "huddle" after:YYYY-MM-DD before:YYYY-MM-DD
content_types: files
```

### 6. Synthesize the summary

Structure the canvas content as follows, in this order:

**Part 1 — Todos (always at the top)**

Include a `## Todos` section with a markdown checklist. Todos come from three sources — merge them, deduplicating by meaning:

1. **Existing todos (from the current canvas):** When updating, copy all existing items exactly, preserving their `- [ ]` / `- [x]` state. Never remove or re-word a todo the user wrote.

2. **Carry-overs (unchecked todos from the previous week's canvas):** Include any unchecked items from last week that aren't already present in the current canvas (deduplicate by meaning). Mark these with a `_(carried over)_` suffix so they're visually distinct, e.g.:
   ```
   - [ ] Follow up with design team on mockups _(carried over)_
   ```
   Place carry-overs after existing todos but before newly suggested ones.

3. **Suggested todos (generated from this week's activity):** Scan the gathered messages for actionable follow-ups — things mentioned but not resolved, blockers waiting on someone, open threads, PRs to review, or commitments made. Add these as new unchecked items. Only suggest items that aren't already covered by an existing or carry-over todo. If no new follow-ups are apparent, add nothing.

The final order: user-written todos first (original order), then carry-overs from last week, then newly suggested ones. When creating a fresh canvas with no prior todos, only include carry-overs and suggested items.

**Part 2 — Meetings**

If any huddle notes were found for the week, include a `## Meetings` section. List each huddle as a bullet with the meeting title (or date if no title), a link to the huddle notes canvas, and a one-line summary of key decisions or topics:

```
## Meetings

- [Huddle notes – Monday, 2026-03-23](canvas_url) — Discussed onboarding flow redesign; decided to defer auth changes to Q2
- [Huddle notes – Wednesday, 2026-03-25](canvas_url) — Sprint planning; committed to EDA-61, EDA-72
```

If no huddle notes were found, omit this section entirely.

**Part 3 — Daily activity sections**

Create one section per day of the week that has activity, in chronological order. Format each day as:

```
### Monday, YYYY-MM-DD

- Description of activity, [conversation link](url) or [PR #123](url)
- Another item with [ticket EDA-61](url) context
```

Rules:
- Use the day's full name and ISO date as the heading (e.g. `### Monday, 2026-03-23`)
- Each item is a single bullet with a concise description
- Link to the source wherever possible: Slack thread URLs, PR URLs, Linear ticket URLs, etc.
- Skip days with no activity
- Prefer specificity over brevity — include ticket IDs, PR numbers, branch names, and person names when visible

### 7. Create or update the canvas

**If creating:**
```
slack_create_canvas(title="Week of YYYY-MM-DD", content=<markdown>)
```

**If updating:**
```
slack_update_canvas(canvas_id=<id>, content=<markdown>)
```

Return the canvas URL to the user when done.

### 8. Update the master weekly summaries canvas

Read the master canvas (`canvas_id: F0AR14LB214`) using `slack_read_canvas`. This canvas accumulates all weekly summaries, newest at the top.

Prepend a new link for the current week at the top of the existing content. Each entry is a single line:

```
- [Week of YYYY-MM-DD](CANVAS_URL)
```

If an entry for the current week already exists (matched by `Week of YYYY-MM-DD`), **replace** it. Do not duplicate it.

Then update the canvas:
```
slack_update_canvas(canvas_id="F0AR14LB214", content=<full updated content>)
```

### 9. Star the current canvas, unstar previous ones

Search for canvases from previous weeks using `slack_search_public_and_private`:
```
query: "Week of" creator:@andrew.fitzpatrick
content_types: files
```

For each result:
- If it is the **current week's canvas**: star it using `slack_add_star` (or equivalent)
- If it is a **previous week's canvas** and currently starred: unstar it using `slack_remove_star` (or equivalent)

If the Slack MCP does not expose a star/unstar tool, skip this step silently and note it to the user.

### 9. Notify via Slack

After creating or updating the canvas, send a message to the user's own DM (i.e. a message to themselves) using `slack_send_message` that tags them and links the canvas:

```
<@USER_ID> Your weekly summary is ready: <CANVAS_URL|Week of YYYY-MM-DD>
```

This triggers a Slack notification so the canvas doesn't go unnoticed.

---

## Notes

- Use `slack_search_public_and_private` (not `slack_search_public`) — work activity is typically in private channels and DMs. This requires user consent; confirm before proceeding if you haven't already.
- The Monday of the current week: subtract `weekday()` days from today (`Monday=0`). In Python: `today - timedelta(days=today.weekday())`.
- If the search returns 20 results, always check for more pages using the cursor.
- Canvas content must be Markdown. Do not include the title in the content body (it's set separately in the title field). Headers must not exceed depth 3 (`###`).
