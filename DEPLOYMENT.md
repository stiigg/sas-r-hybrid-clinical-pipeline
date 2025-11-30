# Web-Based Pipeline Deployment Guide

This repository implements a complete web-based execution and visualization system for the clinical programming pipeline using GitHub Actions, GitHub Pages, and Shiny.

## Architecture Overview

The deployment consists of three integrated components:

1. **Automated Pipeline Execution** (`run_pipeline.yml`) - Runs ETL/QC/TLF on GitHub Actions
2. **Static Dashboard** (`publish_dashboard.yml`) - Quarto-based results viewer on GitHub Pages
3. **Interactive Shiny App** (`deploy_shiny.yml`) - Dataset explorer deployed to shinyapps.io

## Quick Start

### 1. Enable GitHub Actions

GitHub Actions are enabled by default. The workflows trigger automatically on:
- Push to `main` or `develop` branches (when data/code changes)
- Manual dispatch via GitHub UI: Actions → Select workflow → Run workflow

### 2. Enable GitHub Pages

**Required for dashboard deployment:**

1. Go to: Settings → Pages
2. Source: "Deploy from a branch"
3. Branch: Select `gh-pages` (will be created automatically)
4. Click Save

Your dashboard will be available at: `https://<username>.github.io/<repo-name>/`

### 3. Configure Shiny Deployment (Optional)

**For interactive app deployment to shinyapps.io:**

1. Create free account at [shinyapps.io](https://www.shinyapps.io/)
2. Get credentials: Account → Tokens → Show → Show Secret
3. Add to GitHub: Settings → Secrets → Actions → New repository secret

   Add three secrets:
   - `SHINY_ACC_NAME`: Your shinyapps.io account name
   - `SHINY_TOKEN`: Token from dashboard
   - `SHINY_SECRET`: Secret from dashboard

4. Workflow will deploy automatically after pipeline runs

App will be available at: `https://<account>.shinyapps.io/clinical-pipeline-explorer/`

## Workflow Execution

### Manual Pipeline Execution

1. Navigate to: Actions → Clinical Pipeline Execution
2. Click "Run workflow"
3. Configure options:
   - **Pipeline mode**: `dev`, `near_lock`, or `final_lock`
   - **ETL dry run**: `true` (simulation) or `false` (full execution)
   - **QC dry run**: `true` or `false`
   - **TLF dry run**: `true` or `false`
4. Click "Run workflow"

### Viewing Results

**GitHub Actions Artifacts:**
- Actions → Select completed run → Scroll to "Artifacts"
- Download `pipeline-logs-XXX` for execution logs
- Download `pipeline-outputs-XXX` for generated datasets

**Dashboard:**
- Automatically updates after pipeline completion
- Shows QC reports, run status, output summaries

**Shiny App:**
- Interactive exploration of ADaM datasets
- Filter, search, visualize, export to CSV

## Production Deployment with SAS

**GitHub-hosted runners don't include SAS**. For full pipeline execution:

### Option A: Self-Hosted Runner (Recommended)

1. Set up self-hosted runner on SAS-licensed server:
   - Settings → Actions → Runners → New self-hosted runner
   - Follow platform-specific installation instructions
   - Tag runner as `sas-enabled`

2. Modify `run_pipeline.yml`:
   ```yaml
   runs-on: [self-hosted, sas-enabled]  # Replace ubuntu-latest
   ```

3. Ensure SAS executable in PATH on runner machine

### Option B: Dry-Run Only

Current configuration runs in dry-run mode by default:
- Validates metadata and dependencies
- Tests orchestration logic
- No SAS execution required
- Suitable for CI/CD validation

## Directory Structure

```
.github/workflows/
  ├── ci.yml                  # Existing: Test validation
  ├── run_pipeline.yml        # NEW: Full pipeline execution
  ├── publish_dashboard.yml   # NEW: GitHub Pages deployment
  └── deploy_shiny.yml        # NEW: Shiny app deployment

app/
  └── app.R                   # NEW: Shiny application

dashboard/
  └── index.qmd               # Auto-generated dashboard (created by workflow)
```

## Troubleshooting

### Dashboard not appearing
- Check: Actions → Publish Dashboard → Verify success
- Check: Settings → Pages → Ensure `gh-pages` branch selected
- Wait 2-5 minutes for GitHub Pages propagation

### Shiny app deployment fails
- Verify secrets are correctly named: `SHINY_ACC_NAME`, `SHINY_TOKEN`, `SHINY_SECRET`
- Check shinyapps.io account limits (free tier: 5 apps, 25 hours/month)
- Review workflow logs: Actions → Deploy Shiny App → View logs

### Pipeline execution errors
- Check workflow logs for detailed error messages
- Verify file paths in manifests (`specs/*.csv`)
- Ensure all R dependencies are listed in workflow YAML

### SAS execution issues
- Confirm SAS in PATH on self-hosted runner
- Check SAS license validity
- Verify file permissions on runner machine

## Customization

### Modify Dashboard Content

Edit `publish_dashboard.yml` workflow, section "Create dashboard directory":
```yaml
cat > dashboard/index.qmd << 'EOF'
# Add custom Quarto content here
EOF
```

Or commit `dashboard/index.qmd` directly to repository.

### Change Shiny App Name

Edit `deploy_shiny.yml`:
```yaml
appName = 'your-custom-name',  # Line 49
```

### Adjust Trigger Conditions

Edit workflow `on:` sections:
```yaml
on:
  push:
    paths:
      - 'data/**'      # Add/remove paths
      - 'custom/**'
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
```

## Security Considerations

- Never commit credentials to repository
- Use GitHub Secrets for sensitive data
- Review workflow permissions (Settings → Actions → General)
- Self-hosted runners should be on secure networks
- Regularly rotate shinyapps.io tokens

## Support

For issues:
1. Check GitHub Actions logs for detailed error messages
2. Review this guide's Troubleshooting section
3. Consult workflow YAML files for configuration details

---

**Last Updated**: 2025-11-30
