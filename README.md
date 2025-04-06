# ServerUtils 🛠️

Welcome to ServerUtils! This is a growing collection of handy shell scripts designed to simplify common tasks on self-hosted servers, especially **Debian-based systems** (like those in Proxmox LXCs).

Think of these as simple tools to automate repetitive jobs and keep things running smoothly.

## What's Inside? 📂

All the scripts live inside the [`Scripts/`](./Scripts/) directory, organized into categories. Each category folder contains:

1.  The script(s).
2.  A `README.md` explaining **exactly how to use each script** in that category (including usage, examples, and dependencies).

**Available Categories:**

| Category                                           | Description                                                  |
| :------------------------------------------------- | :----------------------------------------------------------- |
| [`docker/`](./Scripts/docker/)                     | Utilities for managing Docker containers and images. 🐳      |
| [`log-management/`](./Scripts/log-management/)     | Scripts for cleaning and managing system logs. 🪵            |
| [`network/`](./Scripts/network/)                   | Tools for checking network status and information. 🌐        |
| [`system-maintenance/`](./Scripts/system-maintenance/) | Scripts for general system updates and upkeep. 🔧            |

## Getting Started

1.  Browse the [`Scripts/`](./Scripts/) directory and find a category/script that looks interesting.
2.  Read the `README.md` *inside that category's folder* for detailed usage instructions.
3.  Run the scripts! (Use with caution, especially if your environment differs significantly from Debian on Proxmox LXC).

## Want to Contribute? ✨

Found a bug? Have an idea for a new script? Contributions are welcome!

* **Ideas & Bugs:** Please open an [Issue](https://github.com/ShinniUwU/ServerUtils/issues).
* **Code Contributions:** Check out our simple **[Contributing Guide](CONTRIBUTING.md)** to see how you can add your own scripts or improvements using our GitHub Flow process.
* **Be Nice:** Please follow our [Code of Conduct](CODE_OF_CONDUCT.md).

Let's build a useful toolkit together!
