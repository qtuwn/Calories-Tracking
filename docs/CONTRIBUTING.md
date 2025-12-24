# How to Contribute – Calories App

Thank you for your interest in contributing to the Calories App project! This document outlines the development workflow and standards we follow to maintain code quality and collaboration.

## Development Workflow

We use a feature branch workflow with GitHub Pull Requests to manage changes. This ensures code review, automated testing, and a clean project history.

### Step-by-Step Workflow

1. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

2. **Make Your Changes**
   - Write clean, maintainable code following Flutter best practices
   - Add tests for new features or bug fixes
   - Ensure your code passes `flutter analyze`

3. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```
   - Use clear, descriptive commit messages
   - Follow conventional commit format when possible (feat:, fix:, refactor:, docs:)

4. **Push to GitHub**
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Create a Pull Request**
   - Go to the GitHub repository
   - Click "New Pull Request"
   - Select your feature branch targeting `main` or `master`
   - Fill out the PR template with details about your changes
   - Request review from team members

6. **Wait for CI Checks**
   - GitHub Actions will automatically run:
     - Flutter analyze (linting)
     - Flutter tests
     - Android debug build verification
   - **All CI checks must pass before merge**

7. **Address Review Feedback**
   - Make requested changes
   - Push additional commits to the same branch
   - The PR will update automatically

8. **Merge After Approval**
   - Once approved and CI passes, a maintainer will merge your PR
   - After merge to `main`/`master`, the release workflow will automatically build signed release artifacts

## Important Rules

### No Direct Pushes to Main/Master

All changes must go through Pull Requests. Direct pushes to `main` or `master` are not allowed. This ensures:
- Code review happens for all changes
- CI checks run before code enters the main branch
- Project history remains clean and traceable

### Never Commit Secrets

**Critical Security Rule**: Never commit sensitive files to the repository.

**Files to NEVER commit:**
- `.env` files (contains API keys)
- `android/key.properties` (contains signing credentials)
- `android/app/keystore/**` (keystore files)
- Any file containing passwords, API keys, or tokens

These files are already in `.gitignore`. If you accidentally commit them:
1. Remove them from git history immediately
2. Rotate any exposed secrets
3. Notify the team

### CI Must Pass Before Merge

All Pull Requests must pass the CI pipeline before they can be merged:
- Flutter analyze must pass (no linting errors)
- All tests must pass
- Debug build must succeed

If CI fails, fix the issues and push new commits. The CI will re-run automatically.

## Code Standards

### Flutter Best Practices

- Follow Flutter style guidelines
- Use meaningful variable and function names
- Keep functions focused and single-purpose
- Add comments for complex logic
- Write tests for new features

### Code Review Guidelines

When reviewing PRs:
- Be constructive and respectful
- Focus on code quality and maintainability
- Ask questions if something is unclear
- Approve when the code meets standards

## Getting Help

If you need help:
- Check existing documentation in the `docs/` directory
- Review similar code in the codebase
- Ask questions in PR comments
- Reach out to the maintainers

## Testing

Before submitting a PR:
- Run `flutter analyze` locally
- Run `flutter test` to ensure all tests pass
- Test your changes on a physical device or emulator
- Verify the app builds successfully

## Release Process

After your PR is merged to `main`/`master`:
- The release workflow automatically triggers
- A signed Android App Bundle (AAB) and APK are built
- Artifacts are available in the GitHub Actions tab
- These can be uploaded to Google Play Console or distributed for testing

## Questions?

If you have questions about the contribution process, please open an issue or contact the maintainers.

Thank you for contributing to Calories App!

