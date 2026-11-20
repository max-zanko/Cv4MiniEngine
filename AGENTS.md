# Working in this repository

Use subagents for substantial investigations and implementation work when an
independent task can be delegated. In particular, delegate crash reproduction,
log/backtrace analysis, or an independent review while the primary agent
coordinates the work and verifies the result.

Give each subagent a clear scope and ownership of files to avoid overlapping
edits. Share relevant findings between agents, and report the verified outcome
to the user.

Keep toolchains and dependency installations isolated in Docker. Do not install
host-wide packages. Use the pinned source submodules and the Docker workflow
in BUILDING.md. Preserve existing user configuration, saves, and crash evidence
when reproducing failures.
