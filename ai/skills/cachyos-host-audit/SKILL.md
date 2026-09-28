---
name: cachyos-host-audit
description: Non-destructive audit of a CachyOS host with Hyprland, Noctalia, capabilities, bundles, NVIDIA, gaming, Btrfs and systemd. Use when diagnosing the machine, reviewing dotfiles changes against the live host, assessing maintenance or preparing a change that depends on real hardware and services.
---

# CachyOS Host Audit

## Goal

Collect evidence while keeping the reproducible validity of the dotfiles
separate from the live state. Produce prioritized findings. Never change
packages, services, `/etc`, GPU, boot, Btrfs or devices.

## Flow

1. Read the applicable `AGENTS.md` and locate the dotfiles repository.
2. Run the reproducible checks first, when available:

   ```bash
   just lint
   ```

3. Then run the read-only wrapper from the skill directory:

   ```bash
   bash scripts/host-audit.sh
   ```

4. If the repository doctor is missing, collect by hand only the evidence the
   question needs. Never replace a failed inspection with an assumption.
5. Classify each result as failure, risk, warning or observation. Separate the
   proposed configuration, the deployed state and actions not yet authorized.
6. Recommend the smallest reversible change. Do not apply it unless asked; for
   `/etc` or services require the exact target and a prior backup.

## Safety limits

- On Arch/CachyOS use Pacman or Shelly, never `apt`.
- CHWD owns the NVIDIA driver.
- Never read `.env` files or print variables that may hold secrets.
- Do not enable units, change parameters, mount, unmount or write to `/sys`,
  `/proc`, `/etc` or devices during the audit.
- Use `pkexec` only in an apply phase the user requested, never to diagnose.
- Check [references/checklist.md](references/checklist.md) before closing.

## Delivery

Summarize the overall state first. Then list findings by priority with
evidence, impact, recommended change and rollback. End with the checks that ran
and the risks that could not be verified on the current host.
