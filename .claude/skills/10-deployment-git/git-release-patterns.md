---
name: git-release-patterns
description: "Git release patterns including pre-commit validation, branch workflows, and release procedures for Rust workspaces. Use for 'pre-commit', 'release checklist', 'version bump', or 'PR workflow'."
---

# Git Release Patterns

> **Skill Metadata**
> Category: `git`
> Priority: `HIGH`
> Tools: git, cargo, clippy, rustfmt, cargo-audit

## Pre-Commit Validation

### Quality Pipeline (MANDATORY)

```bash
# Run before EVERY commit
cargo fmt --all --check          # Rust code formatting
cargo clippy --workspace -- -D warnings  # Linting (zero warnings)
cargo test --workspace           # Run tests
cargo audit                      # Dependency vulnerability check

# All-in-one check
cargo fmt --all --check && \
cargo clippy --workspace -- -D warnings && \
cargo test --workspace && \
cargo audit && \
echo "Ready to commit"
```

### Quality Gate Checklist

```
- [ ] cargo fmt --all --check → No formatting changes needed
- [ ] cargo clippy --workspace -- -D warnings → No lint violations
- [ ] cargo test --workspace → All tests pass
- [ ] cargo audit → No known vulnerabilities
- [ ] git status → All changes staged
```

## FORBIDDEN Git Commands

```bash
# NEVER USE - Destructive operations
git reset --hard    # Can lose work
git push --force    # Can overwrite others' work

# SAFE ALTERNATIVES
git stash          # Temporarily save changes
git commit         # Commit changes safely
git revert         # Undo a commit safely
```

## Branch Workflow

### Feature Development

```bash
# 1. Create Feature Branch (REQUIRED)
git checkout main
git pull origin main
git checkout -b feat/descriptive-name

# 2. Development Loop
# Make changes
cargo fmt --all                         # Format code
cargo clippy --workspace -- -D warnings # Lint
cargo test --workspace                  # Test
git add specific-files.rs               # Stage specific files
git commit -m "feat(core): implement feature description"

# 3. Pre-Push Validation (MANDATORY)
cargo fmt --all --check && \
cargo clippy --workspace -- -D warnings && \
cargo test --workspace && \
cargo audit
```

### PR Creation

```bash
# Push Feature Branch
git push -u origin feat/descriptive-name

# Create PR with gh CLI
gh pr create --base main --title "feat(core): add feature" --body "$(cat <<'EOF'
## Summary
- What changed and why

## Crates Affected
- `kailash-core`

## Test plan
- [ ] `cargo test --workspace` passes
- [ ] `cargo clippy --workspace -- -D warnings` clean
- [ ] Manual testing completed
EOF
)"
```

## Version Management

### Update Version in Cargo.toml

```bash
# If using workspace version inheritance:
# Edit workspace Cargo.toml
vim Cargo.toml  # [workspace.package] version = "x.y.z"

# If per-crate versioning:
vim crates/kailash-core/Cargo.toml      # version = "x.y.z"
vim crates/kailash-dataflow/Cargo.toml
vim crates/kailash-nexus/Cargo.toml
vim crates/kailash-kaizen/Cargo.toml
vim crates/kailash-enterprise/Cargo.toml
```

## Release Branch Workflow

```bash
# 1. Create Release Branch
git checkout main
git pull origin main
git checkout -b release/v0.1.0

# 2. Pre-Release Validation
cargo fmt --all --check && \
cargo clippy --workspace -- -D warnings && \
cargo test --workspace && \
cargo audit

# 3. Build and Test Release Binary
cargo build --workspace --release

# 4. Test Python Wheels (if applicable)
cd bindings/kailash-python && maturin build --release
pip install target/wheels/kailash_enterprise-*.whl
python -c "import kailash; print(kailash.__version__)"

# 5. Dry-run crates.io publish
cargo publish --dry-run -p kailash-value
cargo publish --dry-run -p kailash-core

# 6. Push Release Branch
git push -u origin release/v0.1.0
```

## GitHub Release Process

```bash
# 1. After PR Merge
git checkout main
git pull origin main
git tag v0.1.0
git push origin v0.1.0

# 2. Create GitHub Release (triggers CI)
gh release create v0.1.0 --title "v0.1.0" --notes "Release notes here"

# 3. crates.io Publish (dependency order)
cargo publish -p kailash-value       # Leaf crate first
cargo publish -p kailash-core        # Then core
cargo publish -p kailash-macros      # Then macros
cargo publish -p kailash-nodes       # Then consumers
# ... etc

# 4. PyPI Upload (via CI or manual)
cd bindings/kailash-python
maturin publish --username __token__ --password $PYPI_TOKEN
```

## Validation Tiers

```bash
# Quick Check (1 minute)
cargo fmt --all --check && cargo clippy --workspace -- -D warnings

# Standard Check (3 minutes)
cargo fmt --all --check && \
cargo clippy --workspace -- -D warnings && \
cargo test --workspace

# Full Validation (5 minutes)
cargo fmt --all --check && \
cargo clippy --workspace -- -D warnings && \
cargo test --workspace && \
cargo audit && \
cargo build --workspace --release

# Release Validation (10 minutes)
cargo fmt --all --check && \
cargo clippy --workspace -- -D warnings && \
cargo test --workspace && \
cargo test --workspace --features integration && \
cargo audit && \
cargo build --workspace --release && \
cargo publish --dry-run -p kailash-value
```

## Emergency Procedures

```bash
# Rollback Release
git tag -d v0.1.0                    # Delete local tag
git push origin :refs/tags/v0.1.0    # Delete remote tag

# Urgent Hotfix
git checkout main && git pull
git checkout -b hotfix/critical-issue
# Make minimal fix
cargo fmt --all --check && \
cargo clippy --workspace -- -D warnings && \
cargo test --workspace
git push -u origin hotfix/critical-issue
# Create PR with "hotfix" label
```

<!-- Trigger Keywords: pre-commit, release checklist, version bump, PR workflow, git branching, feature branch, release branch, crates.io publish, cargo publish -->
