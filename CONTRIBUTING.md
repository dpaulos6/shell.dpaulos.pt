# Contributing

This project is intentionally Windows-first and PowerShell-first for now.

Priorities:

1. Safety: never delete user profile content outside managed blocks.
2. Idempotency: running install/update repeatedly should not duplicate blocks.
3. CurrentUser scope by default.
4. Keep user customizations in `~/.paulos-shell/local.ps1`.
5. Add Bash/CMD support only after the PowerShell module is stable.
