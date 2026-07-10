# TICKETS

`tickets.md` (the project's Kanban board, at the repo root) is provided at start of context. Parse it to understand the backlog. Domain vocabulary comes from `CONTEXT.md`; architectural decisions from `docs/adr/0001`-`0003`.

Work the frontier: pick a ticket whose "Blocked by" items are all already done (checklist fully checked off). If several qualify, prefer the one listed first in the file.

You've also been passed a file containing the last few commits. Review these to understand what work has been done.

If every ticket's checklist is fully checked off, output <promise>NO MORE TASKS</promise>.

# TASK SELECTION

Pick the next task. Prioritize tasks in this order:

1. Critical bugfixes
2. Development infrastructure

Getting development infrastructure like tests and types and dev scripts ready is an important precursor to building features.

3. Tracer bullets for new features

Tracer bullets are small slices of functionality that go through all layers of the system, allowing you to test and validate your approach early. This helps in identifying potential issues and ensures that the overall architecture is sound before investing significant time in development.

TL;DR - build a tiny, end-to-end slice of the feature first, then expand it out.

4. Polish and quick wins
5. Refactors

# EXPLORATION

Explore the repo.

# IMPLEMENTATION

Use /tdd to complete the task.

# FEEDBACK LOOPS

Before committing, run the feedback loops for this Daml project:

- `daml build` to compile
- `daml test` (or the Daml Script scenarios named in the ticket) to run tests

If this tooling doesn't exist yet (e.g. no `daml.yaml`), setting it up is part of the first ticket.

# COMMIT

Make a git commit. The commit message must:

1. Include key decisions made
2. Include files changed
3. Blockers or notes for next iteration

# THE TICKET

If the task is complete, check off its checklist items in `tickets.md`.

If the task is not complete, add a short note under the ticket in `tickets.md` describing what was done and what's left.

# FINAL RULES

ONLY WORK ON A SINGLE TASK.