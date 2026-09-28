# Closing checklist

- Kernel and distribution identified.
- CHWD profile and `nvidia-smi` consistent; no other driver proposed.
- Failed units and relevant timers inspected.
- Subvolume, filesystem and Snapper policy identified before touching Btrfs.
- Hyprland and Noctalia validated by their own tools, when available.
- Composition resolved and capability changes checked before the live state.
- Gaming packages and Ananicy/GameMode coexistence checked only when a gaming bundle is selected.
- Backup state separated from credential presence; values never shown.
- `/etc` or service changes left as a proposal with target and rollback.
- Differences between the working branch, deployed dotfiles and live host explained.
