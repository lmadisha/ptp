---
name: new-adr
description: Create the next numbered Architecture Decision Record in docs/adr and add it to the index. Use when a change affects architecture, stored data, detection behaviour, minimum OS versions, or any hard rule in AGENTS.md.
argument-hint: "<decision as a short statement>"
---

# New ADR

1. List `docs/adr/` and take the highest `NNNN` + 1, zero-padded to 4 digits.
2. Create the filename: `NNNN-<kebab-case-slug>.md`, with the slug from the decision (max 6 words).
3. Fill in the template from `docs/adr/README.md`:
   - **Status:** `Proposed`. Only the human marks it `Accepted`.
   - **Date:** today, `YYYY-MM-DD`.
   - **Context:** the facts and constraints, with links to Apple docs where relevant.
   - **Decision:** one paragraph or a short list. Be specific: values, APIs, versions.
   - **Consequences:** include the downsides and what would make us revisit it.
4. If it replaces an earlier ADR:
   - set the old one's status to `Superseded by ADR-NNNN`
   - change nothing else in the old ADR
5. Add a row to the table in `docs/adr/README.md`.
6. If it relaxes a hard rule in `AGENTS.md` (for example, it allows a network call), update `AGENTS.md` and the matching hook in `.claude/hooks/` in the same change, and flag this clearly to the human.

Keep it under one page. ADRs record why, not how.
