# Coding Policy

## Core Rule

- Do not evaluate a code change only by whether it works.
- Evaluate it in light of the whole codebase: architecture, cohesion, consistency, dependency direction, maintenance burden, and likely future extension points.
- Prefer changes that reduce entropy. Avoid changes that merely local-fix the prompt while making the system uglier.

## Context Discipline

- Read enough surrounding code to understand how the touched area fits into the broader system.
- Check for existing abstractions, utilities, patterns, and architectural boundaries before adding new code.
- Prefer extending or simplifying existing structures over introducing parallel ones.
- Do not add a new helper, type, component, hook, service, script, or abstraction unless existing options were considered and rejected for a stated reason.
- Consider adjacent modules and likely follow-on changes, not just the file named in the prompt.

## Anti-Spaghetti Rules

- Do not solve tasks by layering ad hoc conditionals, flags, wrappers, or one-off utilities onto a weak design unless that tradeoff is explicitly justified.
- Do not duplicate logic because it is locally convenient.
- Do not introduce naming, file, or abstraction patterns that drift from the rest of the codebase without a strong reason.
- Prefer deletion, consolidation, and simplification over additive patches.
- Treat unnecessary code growth as a bug.

## Change Design

- For substantive changes, consider at least two plausible approaches before implementation.
- Choose the approach that best preserves or improves codebase cohesion, not just the fastest local fix.
- Prefer modifying existing abstractions over creating new ones, unless deletion or simplification was considered first and rejected for a stated reason.
- Explicitly critique the chosen approach for regressions, edge cases, failure modes, and long-term maintainability.
- If the correct fix is larger but materially cleaner, say so.

## Verification

- Review your own work after editing.
- Look specifically for behavioral regressions, edge cases, naming problems, dead code, missing validation, unclear abstractions, and architecture drift.
- Run relevant tests, linters, or checks unless blocked by time, environment, permissions, or explicit user instruction.
- If verification is incomplete, say exactly what was not verified and why.

## Reviews

- When asked to review code, lead with findings rather than summary.
- Prioritize bugs, regressions, security issues, missing tests, architecture drift, unjustified complexity, and cohesion problems.
- Call out code that is functional but structurally harmful.
- Include concrete references to files and lines when possible.
- If no issues are found, say that explicitly and state residual risks or testing gaps.
