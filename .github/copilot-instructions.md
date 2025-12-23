# Adoptium Infrastructure Repository

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the information here.

The Adoptium Infrastructure repository manages build farm infrastructure using Ansible playbooks, Docker configurations, and automated testing. This is an Infrastructure-as-Code project, NOT a traditional software build project.

## Working Effectively

### Prerequisites and Setup
- Python 3.x is required and available at `/usr/bin/python3`
- Ansible is required: `pip install ansible ansible-lint`
- Docker is available for container testing
- yamllint is available for YAML validation

### Core Operations

#### Linting (ALWAYS run before committing)
- `yamllint .` -- Takes ~2 seconds. ALWAYS run this for YAML validation
- `ansible-lint --offline` -- Takes ~60 seconds but may show collection warnings (expected in offline environments)
- NEVER COMMIT without running linting. The CI will fail if linting issues exist.

#### Testing Ansible Playbooks  
- Basic connectivity test: `ansible localhost -m ping -i ansible/hosts` where hosts contains `localhost ansible_connection=local`
- CANNOT run full playbooks without internet access (requires Galaxy collections)
- In CI/production, playbooks run with: `ansible-playbook -i hosts playbooks/AdoptOpenJDK_Unix_Playbook/main.yml --skip-tags="adoptopenjdk,jenkins,nagios,superuser,docker"`

#### Docker Container Testing
- Docker builds take 15-45+ minutes depending on the target OS. NEVER CANCEL Docker builds.
- Test Docker build: `docker build -f ansible/docker/Dockerfile.Alpine3 . --build-arg git_sha=test`
- **ACTUAL MEASURED TIME**: Alpine3 build attempted ~5 minutes before failing on network issues (expected in restricted environments)
- Production builds run via GitHub Actions workflows in `.github/workflows/build.yml`

#### Vagrant Testing (if available)
- `chmod +x ansible/pbTestScripts/vagrantPlaybookCheck.sh`
- `ansible/pbTestScripts/vagrantPlaybookCheck.sh --help` to see options
- Vagrant tests take 60-90 minutes to complete. NEVER CANCEL these operations.
- Set timeout to 120+ minutes for any Vagrant-based testing

## Timeout Requirements and Build Times

### CRITICAL: NEVER CANCEL these long-running operations:
- **Docker builds**: 15-45 minutes (set timeout to 60+ minutes, measured 5+ minutes before network failure)
- **Vagrant playbook tests**: 60-90 minutes (set timeout to 120+ minutes) 
- **Ansible playbook execution**: 30-60 minutes (set timeout to 90+ minutes)
- **JDK builds in test scenarios**: 45+ minutes (set timeout to 90+ minutes)

### Fast Operations (< 5 minutes):
- `yamllint .`: ~2 seconds
- `ansible-lint --offline`: ~60 seconds (may show expected collection warnings)
- Basic ansible connectivity tests: < 5 seconds

## Validation Scenarios

### After Making Infrastructure Changes:
1. **ALWAYS** run linting: `yamllint .` and `ansible-lint --offline`
2. **ALWAYS** test basic ansible connectivity: `ansible localhost -m ping -i ansible/hosts`
3. For playbook changes, run relevant GitHub Actions workflow tests (done automatically on PR)
4. For Docker changes, validate Docker builds complete successfully
5. For major changes, run Vagrant tests: `ansible/pbTestScripts/vagrantPlaybookCheck.sh -a --build --test`

### Repository-Specific Validation:
- Changes to `ansible/playbooks/` require testing via GitHub Actions workflows
- Changes to `ansible/docker/` require Docker build validation
- Changes to Vagrant configurations require `vagrantPlaybookCheck.sh` testing
- Always validate timeout settings in playbooks (see `timeout = 60` in ansible.cfg)

## GitHub Actions CI Workflows

The repository uses multiple CI workflows that automatically test changes:

| Workflow File | Platforms | Typical Duration | Notes |
|---|---|---|---|
| `build.yml` | CentOS6, Alpine3 | 15-30 minutes | Docker builds |
| `build_mac.yml` | macOS 13, 14 | 10-20 minutes | Native macOS |
| `build_wsl.yml` | Windows 2019, 2022 | 20-40 minutes | WSL-based |
| `build_vagrant.yml` | Solaris 10 | 45-90 minutes | Vagrant VM |
| `linter.yml` | Ubuntu | 2-5 minutes | YAML/Ansible linting |

**NEVER CANCEL** these CI runs. They automatically validate your changes.

## Key Repository Structure

```
/
├── ansible/                    # Main Ansible configurations
│   ├── playbooks/             # Platform-specific playbooks
│   │   ├── AdoptOpenJDK_Unix_Playbook/    # Unix systems
│   │   ├── AdoptOpenJDK_Windows_Playbook/ # Windows systems  
│   │   └── AdoptOpenJDK_AIX_Playbook/     # AIX systems
│   ├── docker/                # Docker configurations for testing
│   ├── pbTestScripts/         # Playbook testing scripts (Vagrant/QEMU)
│   └── inventory.yml          # Host inventory
├── .github/workflows/         # CI/CD workflows
├── docs/                      # Documentation
└── tools/                     # Utility scripts
```

## Common Tasks and Commands

### Setting Up for Local Development:
```bash
# Create local hosts file for testing
echo "localhost ansible_connection=local" > ansible/hosts

# Test ansible connectivity 
ansible localhost -m ping -i ansible/hosts

# Lint all YAML files
yamllint .

# Lint Ansible files (may show collection warnings offline)
ansible-lint --offline
```

### Understanding Timeout Configurations:
- Ansible timeout: `timeout = 60` (in ansible.cfg)
- Windows operations: `ansible_winrm_operation_timeout_sec: 600`
- Windows read timeout: `ansible_winrm_read_timeout_sec: 630`

### Testing Changes:
- Small changes: Run linting only
- Playbook changes: Wait for GitHub Actions to complete (15-90 minutes)
- Docker changes: Test local Docker build (15-45 minutes)
- Major changes: Run full Vagrant test suite (60-90 minutes)

## Known Limitations

### Offline Environment Issues:
- `ansible-lint` requires internet for Galaxy collections - use `--offline` flag
- Full playbook execution requires `community.general` and `community.windows` collections
- Docker builds work offline but may need base image downloads
- **Docker build failures**: Network issues with older base images (Alpine 3.15) are common in restricted environments

### Platform-Specific Notes:
- macOS requires manual sudoers configuration (see `ansible/MANUAL_STEPS.md`)
- Windows playbooks require WinRM configuration
- AIX has special requirements documented in playbooks

### Troubleshooting Common Issues:
- **"No module named 'ansible_collections.community'"**: Expected when running offline, use `--offline` flag
- **"couldn't resolve module/action"**: Missing collections, expected in offline environments
- **Docker build network errors**: Expected in restricted network environments, builds work in CI
- **Long operation timeouts**: Normal for infrastructure operations, always set high timeout values

## Commit Message Conventions

Prefix commit messages with the area being changed:
- `unixPB:` - Unix playbooks
- `winPB:` - Windows playbooks  
- `aixPB:` - AIX playbooks
- `ansible:` - Ansible configurations
- `vagrant:` - Vagrant scripts
- `docker:` - Docker configurations
- `docs:` - Documentation
- `github:` - GitHub workflows

## IMPORTANT: Always Wait for Completion

This infrastructure project involves long-running operations that are NORMAL and EXPECTED:
- **DO NOT** cancel Docker builds that seem to hang - they can take 45+ minutes
- **DO NOT** cancel Vagrant tests that seem slow - they can take 90+ minutes  
- **DO NOT** cancel Ansible playbook runs - they can take 60+ minutes
- **ALWAYS** set appropriate timeouts (60-120 minutes) when running these operations
- Monitor progress via logs, but be patient with the lengthy operations

The success of infrastructure provisioning depends on allowing these operations to complete fully.