# Bicep Validation and Status Checks

This repository includes automated validation for all Bicep files to ensure code quality, security, and best practices compliance.

## Overview

The validation system includes:

1. **GitHub Actions Workflows** - Automated validation on every push and pull request
2. **Local Validation Script** - Pre-commit validation for developers
3. **Branch Protection** - Required status checks before merging

## GitHub Actions Workflows

### 1. Bicep Validation (`.github/workflows/bicep-validation.yml`)

**Triggers:**
- Push to `main` or `develop` branches (when Bicep files change)
- Pull requests to `main` or `develop` branches (when Bicep files change)

**What it does:**
- ✅ Validates Bicep file syntax
- ✅ Compiles Bicep files to ARM templates
- ✅ Checks individual templates and modules
- ✅ Performs basic best practices validation

### 2. Bicep Lint and Security Check (`.github/workflows/bicep-lint.yml`)

**Triggers:**
- Push to `main` or `develop` branches (when Bicep files change)
- Pull requests to `main` or `develop` branches (when Bicep files change)

**What it does:**
- 🔍 Runs comprehensive linting
- 🔒 Security best practices validation
- 📋 Generates ARM templates as artifacts
- ⚠️  Identifies potential security issues

## Local Development

### Prerequisites

- Azure CLI installed
- Bicep extension for Azure CLI

### Running Local Validation

```powershell
# Basic validation
.\scripts\validate-bicep.ps1

# Detailed validation with best practices
.\scripts\validate-bicep.ps1 -Detailed

# Skip best practices checks (syntax only)
.\scripts\validate-bicep.ps1 -SkipBestPractices
```

### Pre-commit Hook (Optional)

You can set up a pre-commit hook to automatically validate Bicep files:

```bash
# Create pre-commit hook
echo '#!/bin/sh
pwsh -File scripts/validate-bicep.ps1
' > .git/hooks/pre-commit

# Make it executable (Linux/Mac)
chmod +x .git/hooks/pre-commit
```

## Status Checks Configuration

To enable required status checks:

1. Go to repository **Settings** → **Branches**
2. Add branch protection rule for `main`
3. Enable "Require status checks to pass before merging"
4. Add required checks:
   - `Validate Bicep Files`
   - `Bicep Linting and Security`

See [BRANCH_PROTECTION.md](.github/BRANCH_PROTECTION.md) for detailed configuration instructions.

## What Gets Validated

### Syntax and Compilation
- ✅ Bicep syntax correctness
- ✅ Successful compilation to ARM templates
- ✅ Parameter and variable references
- ✅ Resource dependencies

### Security Best Practices
- 🔒 Proper use of `@secure()` decorator
- 🔒 Network security group rules
- 🔒 Public IP address usage
- 🔒 Admin credential handling

### Code Quality
- 📝 `@description` decorators on parameters
- 📝 Consistent naming conventions
- 📝 API version currency
- 📝 Resource naming patterns

## Troubleshooting

### Common Issues

1. **"Bicep not found"**
   ```bash
   az bicep install
   ```

2. **"Syntax error in Bicep file"**
   - Check for missing commas, brackets, or quotes
   - Validate parameter references
   - Ensure resource dependencies are correct

3. **"Missing @description decorator"**
   - Add `@description('Parameter description')` above each parameter

4. **"Potential security issue"**
   - Use `@secure()` for sensitive parameters
   - Review network security rules
   - Avoid hardcoded credentials

### Getting Help

- Check the workflow logs in GitHub Actions
- Run local validation with `-Detailed` flag
- Review the generated ARM templates for issues

## Benefits

- 🚀 **Faster Development** - Catch errors early
- 🔒 **Better Security** - Automated security validation
- 📈 **Higher Quality** - Consistent coding standards
- 🤖 **Reduced Manual Review** - Automated checks reduce reviewer burden
- 📚 **Documentation** - ARM templates provide deployment transparency
