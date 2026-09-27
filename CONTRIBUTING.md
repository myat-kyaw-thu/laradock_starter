# Contributing to LaraDoc Starter

First off, thank you for considering contributing to **LaraDoc Starter**! It's people like you who make this tool better for the entire Laravel community.

## 🤝 Code of Conduct

This project and everyone participating in it is governed by the [LaraDoc Starter Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## 💡 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to ensure it hasn't already been reported.

When creating a bug report, please include as much detail as possible:
* **Operating System** (macOS, Ubuntu, Windows 11, etc.)
* **Docker & Docker Compose versions** (`docker --version`, `docker compose version`)
* **Clear steps to reproduce**
* **Expected vs. actual behavior**
* **Terminal output or logs** (`laradoc logs` or `docker compose logs`)

### Suggesting Enhancements

Feature requests are always welcome! When proposing a new feature:
* Clearly explain **what problem** the feature solves.
* Describe **how it should work** from a developer's perspective.
* Mention any potential breaking changes or trade-offs.

### Submitting a Pull Request

1. **Fork the repository** on GitHub.
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/<your-username>/laradock_starter.git
   cd laradock_starter
   ```
3. **Create a branch** for your feature or bug fix:
   ```bash
   git checkout -b feat/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```
4. **Test your changes**:
   * Test across available operating systems if touching shell/batch scripts.
   * Verify syntax with `bash -n <script.sh>` or `caddy validate`.
   * Ensure backwards compatibility with existing projects.
5. **Commit your changes**:
   * Use clear, descriptive commit messages (Conventional Commits are encouraged, e.g., `feat:`, `fix:`, `docs:`).
6. **Push to your fork** and submit a **Pull Request**.

## 🛠️ Development Guidelines

* **Cross-Platform First:** Whenever modifying scripts, keep macOS (bash/zsh), Linux, and Windows (Batch/PowerShell) in sync.
* **Keep Footprint Lean:** Default services should keep memory consumption under 1GB RAM. Optional services should use Docker Compose profiles (`extras`, `frontend`).
* **Preserve Documentation:** If introducing new CLI commands or changing options, update both `README.md` and the CLI's `laradoc help` command.
