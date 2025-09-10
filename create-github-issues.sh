#!/bin/bash

# Script to create GitHub issues for Babelfish DevTools project
# Usage: First authenticate with `gh auth login`, then run this script

echo "Creating GitHub issues for Babelfish DevTools project..."
echo "Repository: bill-ramos-rmoswi/docker-babelfishpg-devtools"
echo ""

# Check authentication
if ! gh auth status &>/dev/null; then
    echo "Error: Not authenticated with GitHub. Please run: gh auth login"
    exit 1
fi

REPO="bill-ramos-rmoswi/docker-babelfishpg-devtools"

# Create labels
echo "Creating labels..."
gh label create "priority-high" --color "D73A4A" --description "High priority" -R $REPO 2>/dev/null || echo "Label priority-high already exists"
gh label create "priority-medium" --color "FFD700" --description "Medium priority" -R $REPO 2>/dev/null || echo "Label priority-medium already exists"
gh label create "priority-low" --color "0E8A16" --description "Low priority" -R $REPO 2>/dev/null || echo "Label priority-low already exists"

gh label create "feature" --color "A2EEEF" --description "New feature or request" -R $REPO 2>/dev/null || echo "Label feature already exists"
gh label create "enhancement" --color "84B6EB" --description "Enhancement to existing functionality" -R $REPO 2>/dev/null || echo "Label enhancement already exists"
gh label create "refactor" --color "FEF2C0" --description "Code refactoring" -R $REPO 2>/dev/null || echo "Label refactor already exists"
gh label create "documentation" --color "0075CA" --description "Documentation improvements" -R $REPO 2>/dev/null || echo "Label documentation already exists"

gh label create "infrastructure" --color "BFD4F2" --description "Infrastructure and build system" -R $REPO 2>/dev/null || echo "Label infrastructure already exists"
gh label create "backup-restore" --color "5319E7" --description "Backup and restore functionality" -R $REPO 2>/dev/null || echo "Label backup-restore already exists"
gh label create "tools" --color "FBCA04" --description "Developer tools integration" -R $REPO 2>/dev/null || echo "Label tools already exists"
gh label create "cloud" --color "006B75" --description "Cloud integration features" -R $REPO 2>/dev/null || echo "Label cloud already exists"
gh label create "schema-management" --color "B60205" --description "Database schema management" -R $REPO 2>/dev/null || echo "Label schema-management already exists"
gh label create "devcontainer" --color "1D76DB" --description "DevContainer configuration" -R $REPO 2>/dev/null || echo "Label devcontainer already exists"
gh label create "remote-access" --color "C5DEF5" --description "Remote access features" -R $REPO 2>/dev/null || echo "Label remote-access already exists"
gh label create "configuration" --color "F9D0C4" --description "Configuration files and setup" -R $REPO 2>/dev/null || echo "Label configuration already exists"
gh label create "organization" --color "D4C5F9" --description "Code and file organization" -R $REPO 2>/dev/null || echo "Label organization already exists"

echo "Labels created successfully!"
echo ""

# Create milestones
echo "Creating milestones..."
gh api repos/$REPO/milestones -f title="v1.0 - Core Functionality" -f description="Core Babelfish container with backup/restore utilities" --silent || echo "Milestone v1.0 already exists"
gh api repos/$REPO/milestones -f title="v2.0 - Developer Tools" -f description="Integration of developer tools (Compass, AWS CLI, Liquibase)" --silent || echo "Milestone v2.0 already exists"
gh api repos/$REPO/milestones -f title="v3.0 - DevContainer Support" -f description="VS Code DevContainer configuration and setup" --silent || echo "Milestone v3.0 already exists"
gh api repos/$REPO/milestones -f title="v4.0 - Enhanced Features" -f description="Enhanced scripts, documentation, and configuration templates" --silent || echo "Milestone v4.0 already exists"

echo "Milestones created successfully!"
echo ""

# Create Phase 1 issues
echo "Creating Phase 1: Foundation & Core Infrastructure issues..."

gh issue create \
  --title "[CORE] Refactor Dockerfile to organized multi-stage build" \
  --body "## Description
Clean up current monolithic Dockerfile into well-organized stages with clear separation of concerns.

## Acceptance Criteria
- [ ] Separate builder and runner stages clearly
- [ ] Add descriptive comments for each stage
- [ ] Optimize layer caching
- [ ] Test that container builds successfully

## Branch Name
\`feature/issue-1-multi-stage-dockerfile\`" \
  --label "enhancement,infrastructure,priority-high" \
  --milestone "v1.0 - Core Functionality" \
  -R $REPO

gh issue create \
  --title "[FEATURE] Complete BabelfishDump utilities integration" \
  --body "## Description
Ensure bbf_dump and bbf_dumpall are properly built and installed.

## Acceptance Criteria
- [ ] Build from postgresql_modified_for_babelfish repo
- [ ] Version matches BABELFISH_TAG
- [ ] Utilities accessible in PATH
- [ ] Test backup and restore scripts work

## Branch Name
\`feature/issue-2-babelfishdump-integration\`" \
  --label "feature,backup-restore,priority-high" \
  --milestone "v1.0 - Core Functionality" \
  -R $REPO

gh issue create \
  --title "[FEATURE] Configure SSH server for remote access" \
  --body "## Description
Enable SSH access to the container for remote development.

## Acceptance Criteria
- [ ] SSH server starts automatically
- [ ] Secure configuration
- [ ] Port 22 exposed and accessible
- [ ] Document SSH access instructions

## Branch Name
\`feature/issue-3-ssh-configuration\`" \
  --label "feature,remote-access,priority-medium" \
  --milestone "v1.0 - Core Functionality" \
  -R $REPO

# Create Phase 2 issues
echo "Creating Phase 2: Developer Tools Integration issues..."

gh issue create \
  --title "[FEATURE] Add Babelfish Compass compatibility assessment tool" \
  --body "## Description
Download and install latest Babelfish Compass for T-SQL compatibility analysis.

## Acceptance Criteria
- [ ] Download latest Compass release
- [ ] Install with Java runtime
- [ ] Create wrapper scripts
- [ ] Test with sample SQL files

## Branch Name
\`feature/issue-4-babelfish-compass\`" \
  --label "feature,tools,priority-medium" \
  --milestone "v2.0 - Developer Tools" \
  -R $REPO

gh issue create \
  --title "[FEATURE] Install AWS CLI v2 for cloud integration" \
  --body "## Description
Add AWS CLI for S3 backup/restore and cloud operations.

## Acceptance Criteria
- [ ] Install AWS CLI v2
- [ ] Configure IAM role support
- [ ] Update backup scripts for S3 support
- [ ] Test S3 upload/download operations

## Branch Name
\`feature/issue-5-aws-cli\`" \
  --label "feature,cloud,priority-medium" \
  --milestone "v2.0 - Developer Tools" \
  -R $REPO

gh issue create \
  --title "[FEATURE] Add Liquibase for database version control" \
  --body "## Description
Install and configure Liquibase to work with Babelfish via SQL Server protocol.

## Acceptance Criteria
- [ ] Install Liquibase with dependencies
- [ ] Add Microsoft SQL Server JDBC driver
- [ ] Configure for Babelfish connection
- [ ] Create example changelog
- [ ] Test update/rollback operations

## Branch Name
\`feature/issue-6-liquibase\`" \
  --label "feature,schema-management,priority-high" \
  --milestone "v2.0 - Developer Tools" \
  -R $REPO

# Create Phase 3 issues
echo "Creating Phase 3: DevContainer Configuration issues..."

gh issue create \
  --title "[FEATURE] Add VS Code DevContainer support" \
  --body "## Description
Configure devcontainer.json and docker-compose.yml for VS Code integration.

## Acceptance Criteria
- [ ] Create .devcontainer/devcontainer.json
- [ ] Configure docker-compose.yml
- [ ] Add VS Code extensions
- [ ] Configure port forwarding
- [ ] Test with VS Code and Claude Code

## Branch Name
\`feature/issue-7-devcontainer\`" \
  --label "feature,devcontainer,priority-medium" \
  --milestone "v3.0 - DevContainer Support" \
  -R $REPO

gh issue create \
  --title "[REFACTOR] Reorganize repository directory structure" \
  --body "## Description
Create logical directory structure for scripts, tools, and configurations.

## Acceptance Criteria
- [ ] Move scripts to docker/scripts/
- [ ] Create liquibase/ directory
- [ ] Create tools/ directory structure
- [ ] Update Dockerfile paths

## Branch Name
\`feature/issue-8-directory-structure\`" \
  --label "enhancement,organization,priority-low" \
  --milestone "v3.0 - DevContainer Support" \
  -R $REPO

# Create Phase 4 issues
echo "Creating Phase 4: Enhanced Scripts & Automation issues..."

gh issue create \
  --title "[ENHANCEMENT] Add S3 support to backup/restore scripts" \
  --body "## Description
Extend backup_babelfish.sh and restore_babelfish.sh with AWS S3 integration.

## Acceptance Criteria
- [ ] Add --s3-bucket option
- [ ] Implement compression
- [ ] Add retention policies
- [ ] Test S3 upload/download

## Branch Name
\`feature/issue-9-s3-backup-restore\`" \
  --label "enhancement,backup-restore,priority-low" \
  --milestone "v4.0 - Enhanced Features" \
  -R $REPO

gh issue create \
  --title "[FEATURE] Add Liquibase convenience scripts" \
  --body "## Description
Create wrapper scripts for common Liquibase operations.

## Acceptance Criteria
- [ ] Create liquibase-status.sh
- [ ] Create liquibase-update.sh
- [ ] Create liquibase-rollback.sh
- [ ] Add to container PATH

## Branch Name
\`feature/issue-10-liquibase-scripts\`" \
  --label "feature,schema-management,priority-low" \
  --milestone "v4.0 - Enhanced Features" \
  -R $REPO

# Create Phase 5 issues
echo "Creating Phase 5: Testing & Documentation issues..."

gh issue create \
  --title "[FEATURE] Create environment configuration templates" \
  --body "## Description
Create .env.example and configuration templates.

## Acceptance Criteria
- [ ] Create .env.example
- [ ] Create liquibase.properties template
- [ ] Document all environment variables
- [ ] Add to .gitignore appropriately

## Branch Name
\`feature/issue-11-env-templates\`" \
  --label "feature,configuration,priority-low" \
  --milestone "v4.0 - Enhanced Features" \
  -R $REPO

gh issue create \
  --title "[DOCS] Update CLAUDE.md documentation" \
  --body "## Description
Document all new features and commands in CLAUDE.md.

## Acceptance Criteria
- [ ] Document Liquibase commands
- [ ] Document backup/restore procedures
- [ ] Document SSH access
- [ ] Document DevContainer usage

## Branch Name
\`feature/issue-12-documentation\`" \
  --label "documentation,priority-low" \
  --milestone "v4.0 - Enhanced Features" \
  -R $REPO

echo ""
echo "✅ All GitHub issues have been created successfully!"
echo ""
echo "You can view them at: https://github.com/$REPO/issues"
echo ""
echo "Next steps:"
echo "1. Review the created issues at the link above"
echo "2. Adjust priorities and assignments as needed"
echo "3. Start working on issues in priority order"
echo "4. Create feature branches using the naming convention specified in each issue"