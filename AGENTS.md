# Private data and credentials

These standing instructions apply to the entire repository.

- Keep private data outside the checkout and Git history. This includes API keys,
  exchange passphrases, passwords, OAuth tokens, session cookies, private SSH keys,
  account information, and personal financial records.
- Store sensitive configuration in the owning user's private profile:
  `%USERPROFILE%\.config\freqtrade\profiles\` on Windows, or
  `~/.config/freqtrade/profiles/` inside the crypto VM. Restrict access to that user
  and load the needed profile explicitly at runtime.
- Keep generated VM files outside Git, including disks, snapshots, memory dumps,
  installation seeds, SSH access files, and artifacts containing private data.
  Credential-free provisioning source may be tracked; its generated output may not.
- Use blank values or obvious placeholders in tracked examples. Never populate a
  tracked example with real credentials, even temporarily.
- Keep secret values out of chat, tool output, logs, reports, commit messages, and
  pull requests. Avoid reading private profiles unless the authorised task needs
  them, and never mount an entire user profile into a research container.
- Before each commit or push, inspect the exact staged paths and content for
  private data and generated VM material. Keep protective ignore rules in place;
  never force-add sensitive files. Remove any discovered private data from the
  proposed change before publishing it, without printing its values.

Before operating the research environment or provisioning scripts, read
[`research/README.md`](research/README.md) for their execution scope and current
runtime boundaries.
