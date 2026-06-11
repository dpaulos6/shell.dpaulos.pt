# Security Policy

The installer edits a user's PowerShell profile, so changes should be reviewed carefully.

Rules:

- Never add telemetry.
- Never collect secrets.
- Never run destructive commands without confirmation.
- Always back up profiles before editing.
- Only edit text inside PaulosShell managed blocks.
