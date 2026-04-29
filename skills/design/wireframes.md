# Wireframes Protocol

When the feature has user-facing UI, produce HTML+CSS wireframes the user reviews in a real browser — then hard-gate on their explicit approval before plan drafting. HTML is the right fidelity: spacing, typography, layout and responsive behavior are all visible, and the same selectors/copy become the hooks E2E tests assert against.

## When to produce wireframes

Read `WIREFRAMES_REQUIRED=$(tcoder-settings get wireframes_required)`.

- `always` — always produce wireframes
- `never` — never produce wireframes
- `auto` (default) — at step 1 of design, ask the user via AskUserQuestion: "Does this change add or modify any user-facing surface (UI, page, widget)?" Yes → produce wireframes. No → skip.

If skipped, do NOT write a Wireframes section in the design doc — the draft-plan gate triggers off that section.

## Files and layout

Save under `<plan-dir>/wireframes/`:

```text
wireframes/
├── index.html          # Navigation hub — links to every screen, with 1-line purpose
├── 01-<screen>.html    # One file per screen or distinct state
├── 02-<screen>.html
└── styles.css          # Shared stylesheet: neutral palette, visible grid, readable type
```

Use semantic HTML with `id`/`data-testid` attributes on interactive elements so E2E tests can reference them. Match real copy where possible — placeholder copy ("Lorem ipsum") causes test drift when real copy lands.

## Approval gate (hard)

1. After generating wireframes, present viewing instructions to the user:

   > Wireframes are written. Open `<plan-dir>/wireframes/index.html` in your browser — or run `cd <plan-dir>/wireframes && python3 -m http.server 8765` and visit `http://localhost:8765`.

2. Use AskUserQuestion with header "Wireframes":
   - **Approve wireframes** → create sentinel: `touch <plan-dir>/.wireframes-approved`
   - **Request changes** → collect the user's feedback as free text, regenerate the affected files, re-ask. Cap at 5 iterations; on the 5th rejection escalate via AskUserQuestion asking whether to keep iterating, switch to a different approach, or abandon the feature.

3. `validate-plan --check-entry <plan.json> --stage draft-plan` refuses to advance when a design doc's `## Wireframes` section is present but `.wireframes-approved` is missing. That's the structural gate — it keeps planning from starting on unreviewed wireframes.

## Design doc linkage

In the design doc write:

- A **Wireframes** section listing each HTML file with a one-line purpose.
- An **E2E Acceptance Scenarios** section — one Given/When/Then scenario per behavior that operationalizes a wireframe. Each scenario starts with a stable `S<n>` id (e.g. `**S1 User signs in:** ...`) and names the wireframe it exercises. These scenarios are what each owning task turns into a failing spec at the start of its TDD cycle.
- A **Scenario Allocation** section — a `| Scenario | Task label |` table mapping every `S<n>` to a provisional task label. The plan-drafter copies these labels verbatim into task names, so write each label the way you'd want a task to read.

Scenarios must be human-verifiable and implementation-independent — "User signs in and lands on dashboard showing their team count" (good), not "login() returns 200" (implementation).

## Tooling

Name the E2E runner in the design doc (e.g. Playwright for browser UIs, Vitest+jsdom for component UIs, Pytest+Selenium for Python stacks). The plan drafter writes this into `plan.json.e2e.command` and `plan.json.e2e.runner`. If the project has no runner yet, an early implementation task is a setup task.
