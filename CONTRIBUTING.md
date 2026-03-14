# Contributing to cjrxtui

Thanks for contributing to `cjrxtui`.

## Workflow

1. Create a branch from `main`
2. Keep changes focused on one concern
3. Run relevant checks before opening a PR
4. Open a pull request with a clear summary and verification notes

Recommended branch names:

- `feat/<short-name>`
- `fix/<short-name>`
- `docs/<short-name>`
- `refactor/<short-name>`

## Commit style

Use small, descriptive commits. A conventional style works well:

- `feat: add modal keyboard dismissal`
- `fix: handle terminal resize redraw`
- `docs: clarify cjpm dependency setup`
- `test: cover list focus navigation`
- `refactor: simplify render diff pipeline`
- `chore: update repository templates`

Guidelines:

- Prefer one logical change per commit
- Explain why the change exists, not only what changed
- Avoid mixing formatting-only edits with behavior changes unless necessary

## Verification

Run the checks that match your change. Typical commands:

```bash
cjpm build
cjpm test --parallel 1
```

## Releases

Use Git tags for releases after the public API and examples are in a stable state.
Suggested format: `v0.1.0`, `v0.1.1`, `v0.2.0`.
