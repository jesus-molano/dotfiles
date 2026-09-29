# Codex adapter

- Invoke skills as `$name`. `reuse-scout` uses the light model with low effort;
  `catalog-writer` uses the main model with medium effort; reviewers use the
  main model with high effort.
- Keep the locally selected model and effort of the main agent.
- Linear: use the read-only `linear` server. `linear-write` stays disabled; a
  temporary write session needs explicit authorization and the skill's flow.
