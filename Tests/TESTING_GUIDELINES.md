# Swift Testing Migration Guidelines

This repository is migrating to Swift Testing (`Testing` module). Use this checklist for every test change.

## Required

- Use `@Suite` and `@Test` for new and migrated tests.
- Use `#expect` for assertions and `#require` for prerequisites.
- Keep Arrange / Act / Assert phases explicit.
- Add `.timeLimit(...)` for async tests that can block or hang.
- Keep tests deterministic: avoid wall-clock waits and polling loops.

## Expressive Patterns

- Prefer parameterized tests for scenario matrices:
  - `@Test(arguments: [...])` with focused per-case values.
- Keep test names behavior-focused and outcome-oriented.
- Use concise, typed fixtures instead of ad-hoc literals when setup gets complex.

## Traits and Organization

- Use suite-level traits for shared config (`.macros(...)`, tags, serialization).
- Tag tests to support selective CI runs (`.tags(.macro)`, `.tags(.runtime)`).
- Use `.serialized` only when state cannot be safely isolated.

## Migration Guardrails

Guardrails are enforced by `Scripts/check-test-guardrails.sh`:

- No wall-clock waits in test sources (`Task.sleep`, `sleep`, `asyncAfter`, etc.).
- No `import XCTest` in targets already migrated to Swift Testing.
