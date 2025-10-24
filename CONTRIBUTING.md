# Contributing to ServerUtils

Hey there! Thanks for thinking about contributing to ServerUtils. This project is a collection of shell scripts I've found useful for my Debian-based servers (like Proxmox LXCs), and I'm happy to share and potentially improve them with your help.

By contributing, please follow our simple [Code of Conduct](CODE_OF_CONDUCT.md).

We use a workflow called **GitHub Flow** to keep things organized. It basically means: **do your work on a separate branch, then propose merging it via a Pull Request.**

## The Basic Flow (GitHub Flow)

Here’s the usual process for making changes:

1.  **Get Latest `main`:** Make sure your local `main` branch is up-to-date with the original repository:
    ```bash
    git checkout main
    git pull upstream main  # Assumes 'upstream' remote points to ShinniUwU/ServerUtils
    ```
2.  **Create a Branch:** Make a new branch for your change off `main`. Name it descriptively, maybe using prefixes like `script/`, `fix/`, or `docs/`:
    ```bash
    # Example: git checkout -b script/add-disk-usage-check
    git checkout -b your-branch-name
    ```
3.  **Make Changes & Commit:** Do your work (write code, fix bugs, add docs). Commit your changes locally with clear messages:
    ```bash
    git add .
    git commit -m "feat: Add script for checking disk usage"
    ```
    * _Tip:_ Try starting commit summaries with a verb (Add, Fix, Update, Refactor, Docs).
4.  **Keep Updated (Optional but Recommended):** If `main` changes while you're working, update your branch:
    ```bash
    git fetch upstream
    git rebase upstream/main # Or use 'git merge upstream/main' if you prefer
    ```
5.  **Push Branch:** Send your branch up to your fork on GitHub:
    ```bash
    git push origin your-branch-name
    ```
6.  **Open a Pull Request (PR):** Go to the `ShinniUwU/ServerUtils` GitHub page. You should see a button to open a PR from your pushed branch.
    * Fill out the PR template that appears – explain *what* your change does and *why*.
7.  **Discuss & Review:** I (or others) might comment on the PR with feedback or questions. Respond to comments and push any necessary follow-up commits to the *same branch* (the PR updates automatically).
8.  **Merge:** Once approved, your PR will be merged into `main`!
9.  **Clean Up:** You can delete your branch after it's merged.

**Key Rule:** Please **don't push directly to the `main` branch**. Always use a branch and Pull Request.

## Adding or Modifying Scripts

We like to keep scripts organized!

* **Structure:** Place scripts in category folders inside `Scripts/` (like `Scripts/system-maintenance/`).
    ```
    ServerUtils/
    └── Scripts/
        ├── some-category/
        │   ├── your-script.sh
        │   └── README.md  <-- Docs go here!
        └── README.md
    ```
* **Documentation (Important!):** Every category folder (e.g., `Scripts/some-category/`) needs a `README.md`. This file **must** describe **each script** in that folder, including at minimum:
    * **Purpose:** What does the script do?
    * **Usage / Examples:** How do you run it? Show command examples.
    * **Dependencies:** What does it need to run (e.g., `bash`, `apt`, `jq`, specific env vars)?
* **SOLEN Standards:** New or updated scripts should follow `docs/SOLEN_SPEC.md`:
    - Accept `--dry-run`, `--json`, `--yes` (or respect `SOLEN_NOOP=1`, `SOLEN_JSON=1`, `SOLEN_ASSUME_YES=1`).
    - Use exit codes: `0` ok, `1` user error, `2` env/deps, `3` partial, `4` refused, `>=10` specific.
    - Emit JSON per `docs/json-schema/solen.script.schema.json` when `--json` is used.
    - Print exact actions under dry‑run and end with `would change N items`.
    - Include a `SOLEN-META` header block below the shebang (name, summary, requires, tags, verbs, outputs, root).
* **Update Main READMEs:** If you add a new script/category, please add it to the list in `Scripts/README.md` and the main `README.md` in the root folder.

### Quick Scripting Tips

* Start scripts with `#!/usr/bin/env bash`.
* Use `set -euo pipefail` near the top to help catch common errors.
* Quote your variables (`"$my_var"`)!

## Reporting Bugs / Suggesting Ideas

* Use the **Issues** tab on the GitHub repository page.
* Check if a similar issue already exists first.
* For bugs, explain how to reproduce it. For ideas, explain the feature and why it's useful.

## Questions?

* Open an Issue and ask! Tag it with the `question` label.

Thanks again for your interest!
