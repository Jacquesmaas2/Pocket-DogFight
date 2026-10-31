# Development Rules

- Read relevant documentation before modifying code.
- Do not implement unrelated or future functionality.
- Keep changes small and coherent.
- Use Godot 4 APIs and typed GDScript where practical.
- Prefer reusable scenes/components; avoid giant scripts.
- Treat multiplayer correctness as a first-class requirement.
- Never trust clients for authoritative game outcomes.
- Every gameplay mechanic must eventually work with touch input.
- Centralize tunable gameplay values.
- Do not over-engineer.
- After changes, check parser errors, broken references, scene paths and multiplayer assumptions.
- Update relevant MD files only when implementation materially changes architecture or behaviour.
- The repository is authoritative for implementation details.
