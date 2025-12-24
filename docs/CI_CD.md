# CI/CD Pipeline – Calories App

## What is CI/CD?

Continuous Integration (CI) and Continuous Deployment (CD) are software engineering practices that automate the process of building, testing, and deploying code. CI ensures code quality by automatically validating changes, while CD automates the release process to produce production-ready artifacts.

In this project, CI/CD is implemented using GitHub Actions, providing automated quality checks and release builds without manual intervention.

## Continuous Integration (CI)

### Purpose

Continuous Integration prevents broken or low-quality code from entering the main codebase. Every change is automatically validated before it can be merged, ensuring that the main branch remains stable and deployable at all times.

### Trigger Conditions

The CI pipeline is triggered automatically when:

- A Pull Request is opened targeting the `main` or `master` branch
- A Pull Request is updated with new commits
- Manual workflow dispatch is triggered

### CI Pipeline Steps

The CI pipeline executes the following validation steps in sequence:

1. **Dependency Resolution**
   - Installs Flutter dependencies using `flutter pub get`
   - Verifies that all required packages are available and compatible
   - Ensures the project can be built with current dependencies

2. **Static Analysis**
   - Runs `flutter analyze` to check code quality
   - Identifies potential bugs, style violations, and code smells
   - Enforces coding standards and best practices
   - Fails the build if critical issues are detected

3. **Unit Testing**
   - Executes the full test suite using `flutter test`
   - Validates that all existing functionality continues to work
   - Ensures new changes don't introduce regressions
   - Provides test coverage feedback

4. **Debug Build Validation**
   - Builds an Android debug APK using `flutter build apk --debug`
   - Verifies that the application compiles successfully
   - Ensures no build-time errors or configuration issues
   - Validates that the project structure is correct

### PR Guard Concept

The CI pipeline acts as a "guard" for Pull Requests. No code can be merged to the main branch unless:

- All CI checks pass successfully
- Code review is approved by authorized team members
- No conflicts exist with the target branch

This ensures that only validated, reviewed code enters the production codebase.

## Branch Protection Strategy

### No Direct Pushes to Main

Direct pushes to the `main` or `master` branch are forbidden. All changes must flow through Pull Requests, which ensures:

- **Code Review**: Every change is reviewed by team members
- **CI Validation**: All automated checks must pass
- **Documentation**: PR descriptions document what changed and why
- **Traceability**: All changes are linked to issues or feature requests

### CI Status Checks Gate Merging

GitHub branch protection rules require that CI status checks pass before a PR can be merged. This means:

- Developers cannot merge their own code without CI approval
- Failed CI checks block merging until issues are resolved
- The main branch remains stable and deployable at all times

## Continuous Deployment (CD)

### Purpose

Continuous Deployment automates the process of creating production-ready release builds. After code is merged to the main branch, the CD pipeline automatically builds signed Android artifacts that can be distributed to users or uploaded to app stores.

### Trigger Conditions

The CD pipeline is triggered automatically when:

- Code is merged to the `main` or `master` branch
- A version tag matching the pattern `v*` is pushed
- Manual workflow dispatch is triggered

### CD Pipeline Steps

The CD pipeline executes the following steps to produce release artifacts:

1. **Environment Setup**
   - Configures the build environment with required tools
   - Sets up Java 17 for Android builds
   - Installs Flutter SDK with the correct version
   - Prepares the build environment

2. **Secure Secret Injection**
   - Reconstructs signing credentials from GitHub Secrets
   - Creates the Android keystore file from Base64-encoded secret
   - Generates `key.properties` file with signing information
   - Injects environment variables (API keys) from secrets
   - Ensures no secrets are exposed in logs or source code

3. **Release Build**
   - Builds Android App Bundle (AAB) for Google Play distribution
   - Optionally builds APK for direct distribution
   - Applies release signing using the injected credentials
   - Optimizes the build for production

4. **Artifact Generation**
   - Uploads signed AAB to GitHub Actions artifacts
   - Uploads signed APK to GitHub Actions artifacts
   - Makes artifacts available for download
   - Retains artifacts for a specified period

### Release Artifacts

The CD pipeline produces two types of release artifacts:

- **Android App Bundle (AAB)**: Required format for Google Play Store distribution
- **Android APK**: Alternative format for direct installation or testing

Both artifacts are signed with the production signing key and ready for distribution.

## Secrets Management

### Security Principles

Secrets are managed securely using GitHub Actions Secrets, ensuring that sensitive information never enters source control or build logs.

### Secret Categories

**Signing Credentials**:
- Keystore file (Base64-encoded)
- Keystore password
- Key password
- Key alias

**API Keys**:
- Gemini API key for voice input features
- Other service API keys as needed

### Secret Injection Process

1. **Keystore Reconstruction**: Base64-encoded keystore is decoded and written to the expected file location
2. **Properties File Generation**: `key.properties` is created from individual secret values
3. **Environment Variables**: API keys are injected into `.env` file at build time
4. **Log Suppression**: Build logs are configured to prevent secret exposure

### No Secrets in Source Control

The following files are explicitly excluded from version control:

- `.env` files containing API keys
- `android/key.properties` containing signing credentials
- `android/app/keystore/**` containing keystore files

These files are reconstructed during CI/CD from GitHub Secrets, ensuring they never appear in the repository.

## Release Flow Summary

The complete release flow follows this sequence:

1. **Feature Development**
   - Developer creates a feature branch
   - Implements changes and commits code
   - Pushes branch to GitHub

2. **Pull Request Creation**
   - Developer opens a Pull Request targeting `main`
   - CI pipeline automatically triggers
   - CI runs validation checks

3. **Code Review**
   - Team members review the code
   - Feedback is addressed through additional commits
   - CI re-runs automatically on each update

4. **CI Validation**
   - All CI checks must pass
   - Static analysis must succeed
   - All tests must pass
   - Debug build must succeed

5. **Merge Approval**
   - Code review is approved
   - CI status checks are green
   - PR is merged to `main` branch

6. **Continuous Deployment**
   - CD pipeline automatically triggers on merge
   - Secrets are securely injected
   - Release builds are created
   - Artifacts are uploaded and available

7. **Release Distribution**
   - Signed AAB can be uploaded to Google Play Console
   - Signed APK can be distributed for testing
   - Release is ready for user distribution

## Benefits of This Pipeline

### Stability

- **Prevents Broken Code**: CI catches issues before they reach production
- **Consistent Quality**: All code meets the same quality standards
- **Reduced Bugs**: Automated testing catches regressions early
- **Reliable Builds**: Automated builds eliminate human error

### Team Safety

- **Code Review**: All changes are reviewed before merging
- **Automated Validation**: CI provides objective quality assessment
- **Clear Process**: Standardized workflow reduces confusion
- **Risk Mitigation**: Failed builds prevent problematic releases

### Automation

- **Time Savings**: Manual build steps are eliminated
- **Consistency**: Every build follows the same process
- **Reliability**: Automated processes are more reliable than manual steps
- **Scalability**: Pipeline handles any number of changes efficiently

### Professional Workflow

- **Industry Standards**: Follows best practices used in professional software development
- **Audit Trail**: Complete history of all builds and deployments
- **Reproducibility**: Any build can be reproduced from the same code
- **Documentation**: Pipeline serves as executable documentation of the build process

## Conclusion

The CI/CD pipeline provides a robust, automated workflow that ensures code quality and enables reliable releases. By combining automated validation with secure secret management, the pipeline supports professional software development practices while maintaining security and quality standards.

