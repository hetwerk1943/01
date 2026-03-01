# Contributing to Ultra Security Monitor

Thank you for your interest in contributing! Follow these steps to set up your local fork with an upstream remote so you can keep it in sync with the original repository.

## Fork & Clone

1. **Fork** this repository on GitHub (click the *Fork* button on the top-right of the repo page).

2. **Clone** your fork locally:

```bash
git clone https://github.com/YOUR-USERNAME/Ultra-Security-Monitor.git
cd Ultra-Security-Monitor
```

3. **Add the upstream remote** pointing to the original repository:

```bash
git remote add upstream https://github.com/hetwerk1943/Ultra-Security-Monitor.git
```

4. **Verify your remotes**:

```bash
git remote -v
```

You should see output similar to:

```
origin    https://github.com/YOUR-USERNAME/Ultra-Security-Monitor.git (fetch)
origin    https://github.com/YOUR-USERNAME/Ultra-Security-Monitor.git (push)
upstream  https://github.com/hetwerk1943/Ultra-Security-Monitor.git (fetch)
upstream  https://github.com/hetwerk1943/Ultra-Security-Monitor.git (push)
```

## Keeping Your Fork Up to Date

```bash
git fetch upstream
git checkout main
git merge upstream/main
```

## Submitting Changes

1. Create a new branch for your changes:
   ```bash
   git checkout -b feature/my-feature
   ```
2. Commit your changes and push to your fork:
   ```bash
   git push origin feature/my-feature
   ```
3. Open a **Pull Request** from your branch to `hetwerk1943/Ultra-Security-Monitor:main`.
