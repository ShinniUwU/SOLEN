# Network Utility Scripts 🌐

Scripts for checking network configuration and connectivity.

---

## `network-info.sh`

Displays current IP addresses, listening TCP/UDP ports, and performs a basic internet connectivity check.

### Purpose

Provides a quick overview of the machine's network status. Useful for verifying IP configuration, checking which services are listening, and confirming basic network access.

### Usage

```bash
./network-info.sh
```

### Dependencies

* `bash`
* `ip` (from `iproute2` package)
* `ss` (from `iproute2` package)
* `ping` (from `iputils-ping` package)

### Example Output

```
ℹ️  🌐 Gathering network information...

--- IP Addresses ---
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             192.168.1.100/24 fe80::a00:27ff:fe3b:c4d/64

--- Listening Ports (TCP/UDP) ---
Netid  State   Recv-Q  Send-Q    Local Address:Port      Peer Address:Port Process
udp    UNCONN  0       0             127.0.0.1:323            0.0.0.0:* users:(("chronyd",pid=123,fd=1))
tcp    LISTEN  0       128           127.0.0.1:631            0.0.0.0:* users:(("cupsd",pid=456,fd=7))
tcp    LISTEN  0       5             127.0.0.1:5432           0.0.0.0:* users:(("postgres",pid=789,fd=3))
tcp    LISTEN  0       128             0.0.0.0:22             0.0.0.0:* users:(("sshd",pid=101,fd=3))
tcp    LISTEN  0       128                [::]:80                [::]:* users:(("nginx",pid=202,fd=6))

--- Connectivity Check ---
ℹ️     Pinging 1.1.1.1 (3 times)...
✅    Ping to 1.1.1.1 successful.

✅ ✨ Network information retrieval finished!
```

---

