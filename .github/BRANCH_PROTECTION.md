# Branch Protection and Status Checks Configuration

This document describes the recommended branch protection settings for this repository.

## Required Status Checks

To ensure code quality and security, the following status checks should be configured as required in your repository settings:

### For the `main` branch:

1. **Bicep Validation** (`validate-bicep`)
   - Validates Bicep file syntax and compilation
   - Ensures all Bicep files are well-formed
   - Blocks merging if validation fails

2. **Bicep Lint and Security Check** (`bicep-lint`)
   - Performs linting and security analysis
   - Checks for best practices compliance
   - Generates ARM templates for validation

## How to Configure

1. Go to your repository settings
2. Navigate to "Branches" in the left sidebar
3. Add a branch protection rule for `main`
4. Enable "Require status checks to pass before merging"
5. Add the following required status checks:
   - `Validate Bicep Files`
   - `Bicep Linting and Security`

## Additional Recommendations

- Enable "Require pull request reviews before merging"
- Set "Required number of reviewers" to at least 1
- Enable "Dismiss stale reviews when new commits are pushed"
- Enable "Require review from CODEOWNERS"
- Enable "Restrict pushes that create files that have a path matching the specified patterns" for sensitive files

## Workflow Triggers

The validation workflows will run automatically on:
- Push to `main` or `develop` branches (when Bicep files change)
- Pull requests targeting `main` or `develop` branches (when Bicep files change)
- Manual workflow dispatch

## Benefits

- **Early Error Detection**: Catch syntax errors and issues before code review
- **Security Compliance**: Ensure security best practices are followed
- **Code Quality**: Maintain consistent coding standards
- **Automated Validation**: Reduce manual review overhead
- **Documentation**: Generate ARM templates for transparency
