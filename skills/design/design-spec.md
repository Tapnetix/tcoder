# Design Doc Reference Specification

## Purpose and Audience

A design doc is the **intent contract** between the user and the plan-drafter. It captures what problem is being solved, why, what success looks like, and how the solution is structured — at a level that lets a fresh agent produce a correct implementation plan with zero conversation context.

A design doc is **not**:
- A plan (no task graphs, verification commands, or step-by-step implementation code)
- Code (no implementation logic — file paths and structural descriptions are fine)
- A requirements list (it includes architectural judgment, alternatives, and scope decisions)

The plan-drafter reads the design doc and nothing else. Every assumption, file reference, and scope boundary must be explicit. `bin/validate-design --check <path>` enforces the structural rules below mechanically — run it before dispatching the LLM design-reviewer so the reviewer spends its budget on semantic issues, not missing headings.

---

## File Convention

```text
.claude/tcoder/YYYY-MM-DD-<topic>/design-<topic>.md
```

Example: `.claude/tcoder/2026-04-21-feed-filter/design-feed-filter.md`

---

## Section Structure

Twelve sections total — **eight always required**, **four conditional**. All sections, when present, appear in the canonical order listed. No section may be empty.

| Order | Section | Required |
|---|---|---|
| 1 | `## Problem` | Always |
| 2 | `## Goal` | Always |
| 3 | `## Success Criteria` | Always |
| 4 | `## Wireframes` | When the feature has user-facing UI |
| 5 | `## E2E Acceptance Scenarios` | When Wireframes is present |
| 6 | `## Architecture` | Always |
| 7 | `## Key Decisions` | Always |
| 8 | `## Non-Goals` | Always |
| 9 | `## Implementation Approach` | Always |
| 10 | `## Test Coverage` | When `coverage_mode` setting is not `off` |
| 11 | `## E2E Tooling` | When Wireframes is present |
| 12 | `## Scope Estimate` | Always |

---

## Always-Required Sections

### 1. `## Problem`

**Include:** What is broken or missing, who is affected, what happens if the problem is not solved.

**Constraint:** Must answer "why act now" — not describe the desired feature. A problem statement that describes the solution produces a plan-drafter that doesn't understand what it's optimizing for.

- Anti-pattern: "We need a caching layer." (describes solution)
- Correct: "API response times exceed 2s for 40% of requests during peak load, causing user drop-off. The bottleneck is database read latency."

### 2. `## Goal`

**Include:** One sentence. The concrete, measurable objective this design achieves.

**Constraint:** One sentence only. If the goal needs multiple sentences, the scope is too broad — split into phases.

### 3. `## Success Criteria`

**Include:** Behavioral outcomes a human can verify by observing the system. Each criterion independently checkable.

**Constraints:**
- **Human-verifiable:** Confirm yes/no by observing behavior or outcomes (not by reading code or running tests).
- **Implementation-independent:** No references to specific code, tests, tools, or deployment steps. "Users can log in" — correct. "The middleware passes" / "jest suite passes" — wrong.
- **Collectively complete:** If every criterion passes, the Goal is fully met — no gap.
- **Individually necessary:** Removing any single criterion would leave a part of the Goal uncovered.

### 6. `## Architecture`

**Include:** Components, relationships, and data flow. File paths and code snippets are allowed — they describe structure, not implementation logic. Include enough detail that the plan-drafter knows what to build and how pieces connect.

**Cross-reference rule:** Every file path mentioned here (backticked) must also appear in `## Implementation Approach` (and vice versa), except for `wireframes/*` paths which belong to design artifacts, not source code.

**Constraint:** Every architectural component must trace to a part of the Problem. Components with no problem-driven reason signal scope creep.

### 7. `## Key Decisions`

**Include:** The significant trade-off decisions made during design. For each: what was chosen, what was gained, what was given up, what alternatives were considered with rejection reasons.

**Why it matters:** Prevents the plan-drafter from re-exploring rejected paths and surfaces reasoning that would otherwise live only in the conversation and be lost after approval.

**Minimum per decision:** what was chosen, why (what the choice gains), at least one named alternative with rejection reason.

### 8. `## Non-Goals`

**Include:** Explicit boundaries — things plausibly in scope given the Problem but intentionally excluded.

**Constraint:** Each non-goal requires a rationale of **at least 10 words** explaining why it is excluded. `validate-design` enforces this mechanically — a bare phrase like "No i18n support" is rejected.

**Why it matters:** Agents build plausible things. A bare non-goal leaves that freedom; an explained one is an active constraint.

### 9. `## Implementation Approach`

**Include:** How the solution gets built — file paths, change descriptions, test impact, migration or operational steps.

**Cross-reference rule:** Every file path here (backticked) must also appear in `## Architecture` and vice versa. `wireframes/*` paths are excluded from this rule.

**Required sub-elements:** file change table, test impact note per behavior change, migration/operational steps if data/config/deployment touched.

### 12. `## Scope Estimate`

**Include:** How big is this work? Enough for the user to decide whether to proceed and how to execute it.

**Required elements:** phase count (must mention the word "phase"), task count (must mention the word "task"), recommended execution mode (`subagents` ≤10 tasks single phase; `agent teams` >10 tasks or multi-phase).

**Why it matters:** The user's primary sizing decision. Must live in the doc, not the conversation.

---

## Conditional Sections

### 4. `## Wireframes` — required when the feature has user-facing UI

**Include:** One bullet per wireframe file under `<plan-dir>/wireframes/`, each with a one-line purpose. Paths must be backticked.

```markdown
- `wireframes/01-login.html` — login screen
- `wireframes/02-dashboard.html` — dashboard after sign-in
```

**Triggers:**
- Presence of this section activates the `.wireframes-approved` sentinel gate in `validate-plan --check-entry --stage draft-plan`.
- Presence requires `## E2E Acceptance Scenarios` and `## E2E Tooling` to also be present.

### 5. `## E2E Acceptance Scenarios` — required when Wireframes is present

**Include:** Given/When/Then scenarios, one per observable behavior. Each scenario references at least one wireframe file by backticked path.

```markdown
- **User signs in:** Given the app, when the user submits credentials in `wireframes/01-login.html`, then they land on the dashboard.
```

**Constraints enforced by validate-design:**
- Every wireframe in `## Wireframes` must be referenced by ≥1 scenario (no orphan wireframes).
- Every wireframe referenced in a scenario must be declared in `## Wireframes` (no orphan scenario references).

**Why:** The plan-drafter turns these scenarios into assertions in the `e2e-red` task. Orphans on either side break the red→green gate.

### 10. `## Test Coverage` — required when `coverage_mode` setting is not `off`

**Include:** coverage tool detected (or "none — needs setup"), coverage command, baseline percentage or `null`, threshold from the `coverage_threshold` setting.

Consumed by the plan-drafter to populate `plan.json.coverage`.

### 11. `## E2E Tooling` — required when Wireframes is present

**Include:** E2E runner name (Playwright, Cypress, etc.) and the exact shell command to run the suite, backticked.

Consumed by the plan-drafter to populate `plan.json.e2e.command`. `validate-design` flags this section missing if `## Wireframes` is present.

---

## Design vs Plan Boundary

| Belongs in design | Belongs in plan |
|---|---|
| Problem statement and who is affected | Task graph with dependencies |
| Goal and success criteria | Exact verification commands |
| Architectural components and relationships | Step-by-step implementation instructions |
| File paths (describing "what changes") | File paths (describing "how to change them") |
| Trade-off decisions and alternatives rejected | Code snippets that implement the change |
| Non-goals and scope boundaries | Test fixture content |
| Wireframes and E2E acceptance scenarios | Spec test code generated from scenarios |
| Scope estimate and phase rationale | Per-task status tracking |
| Execution mode recommendation | Completion notes format |

File paths and structural code snippets can appear in both — the design describes **what** changes and **why**, the plan describes **how** to change it.

---

## Writing Guidance

**Target length:** ~1,500 words. Docs longer than 2,000 words usually carry plan-level detail that should be moved, or architecture prose that belongs in a table.

**Explicit structure over prose.** The plan-drafter reads literally. Headers, bullet points, and tables parse more reliably than paragraphs. Avoid "as mentioned above" — the plan-drafter may not have that context anchored.

**Alternatives-considered is the highest-value section** for downstream agents. Every significant Key Decision should name at least one alternative and its rejection reason.

**Non-goals prevent scope creep more reliably than any other section.** Agents fill gaps by building plausible features. An explicit non-goal with rationale is an active constraint; its absence is an implicit invitation.

**Success criteria calibration:** Write each criterion as a sentence starting with "A user can..." or "The system..." and test it against: "Can a person verify this without reading code?" If no, rewrite.

**Architecture prose should describe structure, not mechanism.** "The validator reads the design doc, extracts H2 headings with grep, and returns a list of missing sections" is plan-level. "The validator checks that all required H2 headings are present, in order, with content" is architecture-level.
