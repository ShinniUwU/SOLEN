# Security Scripts 🔐

Security scripts to assess and apply common hardening.

- `baseline-check.sh`
  - Checks sshd (PermitRootLogin, PasswordAuthentication), firewall presence
    (ufw/nftables/iptables), fail2ban service state, time synchronization,
    ASLR (randomize_va_space), and sudoers membership.
  - Output supports `--json` for automation.

- `firewall-status.sh`
  - Reports firewall status across ufw/nftables/iptables.
  - Output supports `--json` and includes raw rule output under details.

- `firewall-apply.sh`
  - Apply safe defaults via ufw (preferred) or nftables/iptables, allow SSH and extra ports.
  - Supports `--service web|http|https|dns|wireguard` to quickly open common ports.
  - Honors `--dry-run` and requires policy token `firewall-apply`.

- `ssh-harden.sh`
  - Harden `sshd_config`: disable root login and password auth by default; optional custom port and groups.
  - Validates with `sshd -t` before applying; supports `--restart` (policy-gated).

Examples:

```
../../serverutils run security/baseline-check -- --json
../../serverutils run security/firewall-status -- --json
../../serverutils run security/firewall-apply -- --ssh-port 22 --allow tcp:80 --allow tcp:443 --dry-run
../../serverutils run security/ssh-harden -- --permit-root no --password-auth no --restart --dry-run
```
