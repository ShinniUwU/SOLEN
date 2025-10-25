# Security Scripts 🔐

Read-only scripts to quickly assess server security posture.

- `baseline-check.sh`
  - Checks sshd (PermitRootLogin, PasswordAuthentication), firewall presence
    (ufw/nftables/iptables), fail2ban service state, time synchronization,
    ASLR (randomize_va_space), and sudoers membership.
  - Output supports `--json` for automation.

- `firewall-status.sh`
  - Reports firewall status across ufw/nftables/iptables.
  - Output supports `--json` and includes raw rule output under details.

Examples:

```
../../serverutils run security/baseline-check -- --json
../../serverutils run security/firewall-status -- --json
```

