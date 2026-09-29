# jenkins-as-code — Agent Context & Design Reference

This document is the **authoritative design reference** for the `jenkins-as-code/` sub-project.
It explains what was built, why each decision was made, the conventions to follow, and what
remains to do. It is written for both human engineers and AI coding agents working on this
sub-project.

---

## Purpose

`jenkins-as-code/` provisions a fully production-equivalent Adoptium Jenkins master from scratch
using Ansible. The goal is that any engineer (or automated process) can:

1. Take a blank Ubuntu 24.04 server (or a Vagrant VM)
2. Run two Ansible playbooks
3. Have a running, hardened Jenkins instance whose configuration mirrors the current production
   Hetzner server

A companion backup/restore script pair captures and reproduces Jenkins application configuration
(plugins, jobs, credentials, nodes) independently of the OS-level provisioning.

---

## Repository layout

```
jenkins-as-code/
├── Vagrantfile                          # Dev VM definition (libvirt, ubuntu/24.04, 8 GB)
├── Vagrant-Scripts/                     # libvirt network startup helpers
├── ansible/
│   ├── group_vars/
│   │   └── all.yml                      # ALL variable defaults live here — single source of truth
│   ├── hosts                            # Minimal INI inventory: localhost ansible_connection=local
│   ├── inventory-vagrant.yml            # Dev overrides: heap=auto, listen=0.0.0.0
│   ├── inventory-production.yml         # Prod overrides: heap=19G, listen=127.0.0.1, IP whitelist
│   ├── inventory-example.yml            # Template to copy for new environments
│   ├── setup-jenkins-host.yml           # Step 1 playbook (OS prep)
│   ├── install-jenkins-server.yml       # Step 2 playbook (Jenkins install)
│   ├── roles/
│   │   ├── README.md                    # Role reference
│   │   ├── system_update/               # apt update + upgrade
│   │   ├── unattended_upgrades/         # Security-only auto-updates
│   │   ├── ntp_config/                  # ntpsec with Ubuntu pool servers
│   │   └── fail2ban/                    # SSH protection + IP whitelist
│   └── templates/
│       ├── jenkins.service.j2           # systemd unit file
│       ├── jenkins-defaults.j2          # /etc/default/jenkins
│       └── jenkins-logrotate.j2         # /etc/logrotate.d/jenkins
├── jenkins-scripts/
│   ├── backup-jenkins-app-config.sh     # Captures JENKINS_HOME config elements
│   ├── restore-jenkins-app-config.sh    # Restores backup with env-specific overrides
│   └── restore-config-overrides.env     # Edit before cross-env restore (URLs, Slack, etc.)
├── data/
│   ├── jenkins-app-backup-*.tar.gz      # Backup tarballs (produced by backup script)
│   └── archive/                         # Planning docs and older backups
├── docs/                                # Operational documentation
│   ├── QUICK-START.md
│   ├── ENVIRONMENT-CONFIG.md
│   ├── PRODUCTION-CONFIG-NOTES.md
│   ├── CONFIG-ANALYSIS.md
│   ├── DEPLOYMENT-GUIDE.md
│   ├── VAGRANT-DEPLOYMENT.md
│   ├── JENKINS-INSTALL.md
│   └── IMPLEMENTATION-SUMMARY.md
└── AGENT-CONTEXT.md                     # ← this file
```

---

## Variable conventions

### Single source of truth

Every variable has a documented default in [`ansible/group_vars/all.yml`](ansible/group_vars/all.yml).
Playbooks and templates **never** contain hard-coded values — they always reference a variable.

Inventory files (`inventory-vagrant.yml`, `inventory-production.yml`) only override values that
differ from those defaults for the specific environment.

### Upgrading Jenkins

When a new Jenkins LTS is released:

1. Update `jenkins_version` in `group_vars/all.yml`
2. Fetch the new checksum: `curl -fsSL https://get.jenkins.io/war-stable/<version>/jenkins.war.sha256`
3. Update `jenkins_war_sha256` in `group_vars/all.yml`

Both values must change together. The `install-jenkins-server.yml` playbook verifies the SHA-256
at download time and fails hard if they do not match.

### Upgrading Java

Change `java_major_version` in `group_vars/all.yml`. The `java_package` and `java_home` variables
are derived from it automatically. The Adoptium APT repository (`packages.adoptium.net`) is used
and is configured by `setup-jenkins-host.yml`.

---

## Two-step deployment model

### Step 1 — `setup-jenkins-host.yml`

Prepares the OS. Safe to run on a fresh or existing Ubuntu 24.04 host.

Execution order:
1. `system_update` role — `apt update && apt upgrade`
2. `unattended_upgrades` role — installs package, writes `/etc/apt/apt.conf.d/50unattended-upgrades` and `20auto-upgrades` (disabled by default — enable manually after testing)
3. `ntp_config` role — installs `ntpsec`, writes `/etc/ntp.conf` with Ubuntu pool servers, enables service
4. `fail2ban` role — installs fail2ban, writes `/etc/fail2ban/jail.local`, enables service
5. Tasks: installs ~60 packages matching the production package list
6. Tasks: installs Temurin JDK (Adoptium APT repo, GPG-verified)
7. Tasks: creates `jenkins` OS user (UID/GID 1000 if available, otherwise system-assigned), SSH key, limits
8. Tasks: SSH hardening — disables password auth, enables pubkey-only, sets MaxAuthTries 3

### Step 2 — `install-jenkins-server.yml`

Installs Jenkins. Requires Step 1 to have run first.

Execution order:
1. Pre-flight assertions: Ubuntu 24.04, `jenkins` user exists, Java installed
2. Environment detection: if `/vagrant` is present → set `effective_listen_address=0.0.0.0`
3. Memory calculation: if `jenkins_heap_size=="auto"` → calculate based on `ansible_memtotal_mb`
4. Downloads `jenkins.war` from `get.jenkins.io`, verifies SHA-256
5. Creates directory structure: `JENKINS_HOME`, `/var/cache/jenkins`, `/var/log/jenkins`
6. Renders templates: `jenkins.service`, `/etc/default/jenkins`, logrotate config
7. Reloads systemd, enables and starts `jenkins.service`
8. Polls `http://localhost:8080/login` until HTTP 200 (30 × 10 s retries)
9. Reads and prints `initialAdminPassword`

---

## Heap auto-sizing

`install-jenkins-server.yml` applies the following logic when `jenkins_heap_size == "auto"`:

| System RAM | Heap |
|---|---|
| < 6 GB | 2G |
| 6 – 14 GB | 4G |
| 14 – 30 GB | 8G |
| 30 GB+ | 19G |

The 30 GB+ tier matches the production Hetzner server. Staging/dev environments with smaller
VMs automatically receive appropriate smaller heaps. Set `jenkins_heap_size: "19G"` (or any
explicit value) in the inventory to pin the heap regardless of detected RAM.

---

## Ansible roles in detail

### `system_update`

Runs `apt update && apt upgrade -y`. Simple, no handlers. Tagged `system_update`.

### `unattended_upgrades`

- Installs `unattended-upgrades`
- Writes `50unattended-upgrades` configured for `*-security` and ESM origins only
- Writes `20auto-upgrades` with both periodic values set to `"0"` (disabled by default)

**⚠ Important:** Automatic updates are intentionally disabled by default. Enable by setting
both values to `"1"` in `/etc/apt/apt.conf.d/20auto-upgrades` after validating on the target
host. This matches production where the security-only cron runs from the root crontab.

### `ntp_config`

- Package: `ntpsec` (overridable via `ntp_package`)
- Service: `ntpsec` (overridable via `ntp_service`)
- Servers: `0-3.ubuntu.pool.ntp.org iburst` + `ntp.ubuntu.com`
- Handler: `restart ntp` fires on `/etc/ntp.conf` change

### `fail2ban`

- Writes `/etc/fail2ban/jail.local` (not `.conf` to avoid upgrade conflicts)
- SSH jail: `maxretry=3`, `findtime=10m`, `bantime=1h`, `backend=systemd`
- Recidive jail: 5+ bans in 24 h → 7-day ban
- Default `ignoreip`: loopback + RFC-1918 private ranges
- **Always override `fail2ban_ignoreip` in your inventory** with your management IPs before
  deploying to any environment that you SSH into. Failure to do this can lock you out.
- Handler: `restart fail2ban` fires on `jail.local` change

---

## systemd service design

[`ansible/templates/jenkins.service.j2`](ansible/templates/jenkins.service.j2) renders to
`/etc/systemd/system/jenkins.service`.

Key decisions:
- `ExecStart` directly invokes `java -jar jenkins.war` using `JAVA_ARGS` and `JENKINS_ARGS`
  from `/etc/default/jenkins` (sourced via `EnvironmentFile`)
- `StandardOutput` and `StandardError` both append to `/var/log/jenkins/jenkins.log`
- `NoNewPrivileges=true` and `PrivateTmp=true` for systemd-level hardening
- `LimitNOFILE=8192` and `LimitNPROC=30654` match production values
- `Restart=on-failure` with `StartLimitBurst=3` in 60 s prevents restart storms

---

## `/etc/default/jenkins` design

[`ansible/templates/jenkins-defaults.j2`](ansible/templates/jenkins-defaults.j2) documents the
full history of JVM flag changes in comments for traceability. Current production settings:

| Flag | Value | Reason |
|---|---|---|
| `-Xmx` | auto or fixed | See heap auto-sizing above |
| `RESULT_CACHE_ENABLED=false` | JUnit memory fix | issue #4364 (2026-05-28) |
| `PREVIOUS_TEST_RESULT_BACKTRACK_BUILDS_MAX=1` | JUnit memory fix | issue #4364 |
| `XStream2.collectionUpdateLimit=-1` | Prevents XStream limit errors | issue #4364 area |
| GC logging | 5×50 MB rotating | Performance analysis |
| `--sessionTimeout=720` | 12-hour sessions | Balance security/UX |
| `--sessionEviction=43200` | 12-hour eviction | Added 2024-05-09 |
| `--accessLoggerClassName=...` | Winstone access log | Added 2019-03-21 |
| `--httpListenAddress` | `127.0.0.1` (or `0.0.0.0` in Vagrant) | Require reverse proxy in prod |

The `effective_listen_address` variable is set at run time by `install-jenkins-server.yml`
based on Vagrant detection, not statically in `group_vars/all.yml`.

---

## Backup script design

[`jenkins-scripts/backup-jenkins-app-config.sh`](jenkins-scripts/backup-jenkins-app-config.sh)

### Philosophy

Captures only **application configuration** — not OS-level config (that is `extract-jenkins-master-config.sh`'s job) and not build data (`jobs/`, `workspace/` are explicitly excluded).

### Archive format

Outer tarball: `jenkins-app-backup-YYYYMMDD-HHMMSS.tar.gz`
Contains inner named tarballs:
- `config.tar.gz` — all `*.xml` files in `JENKINS_HOME` root (config.xml, credentials.xml, etc.)
- `users.tar.gz` — `users/` subtree
- `secrets.tar.gz` — `secrets/`, `.key`, `secret.key`, `secret.key.not-so-secret`
- `plugins.tar.gz` — `plugins/` (enables exact version restore)
- `nodes.tar.gz` — `nodes/` (agent XML definitions)
- `crontab.txt` — jenkins user crontab, plain text

The inner-tarball-per-element design allows the restore script to skip individual elements
(e.g. `--skip plugins` to keep existing plugins when only restoring config).

### Environment variables

| Variable | Default |
|---|---|
| `JENKINS_HOME` | `/home/jenkins/.jenkins` |
| `JENKINS_USER` | `jenkins` |

---

## Restore script design

[`jenkins-scripts/restore-jenkins-app-config.sh`](jenkins-scripts/restore-jenkins-app-config.sh)

### Flow

1. Parse `--skip` and `--blank-oauth` flags
2. Source `restore-config-overrides.env` if present
3. Pre-flight: root check, backup file exists, jenkins user exists
4. Stop Jenkins service (if running)
5. Extract outer tarball to a temp dir
6. For each element (config, users, secrets, plugins, nodes):
   - `config` is special: extracted to a staging subdir → overrides applied → `cp -a` into JENKINS_HOME
   - All others: `tar -xzf` directly into JENKINS_HOME
7. Restore crontab (skip if file is comment-only)
8. `chown -R jenkins:jenkins $JENKINS_HOME`
9. If `--blank-oauth`: create `users/admin/config.xml` with bcrypt-hashed random password
10. `systemctl daemon-reload && systemctl start jenkins`
11. Poll for HTTP 200 on port 8080
12. Print summary including admin password if `--blank-oauth` was used

### Config override mechanism

`restore-config-overrides.env` contains shell variables that are loaded before restoring.
The `apply_override <file> <xml-element> <new-value>` helper performs an in-place `sed`
replacement on the staged file. Empty values are no-ops — a blank env file is safe.

Fields that are always updated from env variables:

| Variable | XML element | File |
|---|---|---|
| `JENKINS_URL` | `jenkinsUrl` | `jenkins.model.JenkinsLocationConfiguration.xml` |
| `JENKINS_URL` | `hudsonUrl` | `hudson.tasks.Mailer.xml` |
| `JENKINS_URL` | `logoPath` (URL prefix only) | `CustomHeaderConfiguration.xml` |
| `JENKINS_ADMIN_EMAIL` | `adminAddress` | `jenkins.model.JenkinsLocationConfiguration.xml` |
| `THINBACKUP_PATH` | `backupPath` | `org.jvnet.hudson.plugins.thinbackup.ThinBackupPluginImpl.xml` |
| `SLACK_TEAM_DOMAIN` | `teamDomain` | `jenkins.plugins.slack.SlackNotifier.xml` |
| `SLACK_DEFAULT_ROOM` | `room` | `jenkins.plugins.slack.SlackNotifier.xml` |

Fields that are always **blanked unconditionally** (no env variable):
- Ansible Tower: `<towerURL>`, `<towerDisplayName>` in `org.jenkinsci.plugins.ansible_tower.AnsibleTower.xml`
- Build queue (`queue.xml`) is always cleared to avoid restoring stale queued jobs

### `--blank-oauth` behaviour

Used when restoring to a different environment where the production GitHub OAuth app cannot be
reused (different URL, different allowed-callback domain).

What it does:
1. Replaces `<securityRealm class="org.jenkinsci.plugins.GithubSecurityRealm...">` with
   `<securityRealm class="hudson.security.HudsonPrivateSecurityRealm">` via Python multiline regex
2. Clears `<clientID>` and `<clientSecret>` in `config.xml`
3. Grants `USER:hudson.model.Hudson.Administer:admin` to the local `admin` user in the authz matrix
4. Creates `users/admin/config.xml` with a bcrypt-hashed random 16-char password
5. Uses `users/admin/` (not a hashed subdir) — Jenkins migrates this to the HMAC-keyed path on startup

The local admin user's password is printed in a box at the end of the restore output. **Change it
after first login.**

---

## Vagrant environment

[`Vagrantfile`](Vagrantfile):
- Box: `bento/ubuntu-24.04`
- RAM: 8192 MB, CPUs: 2, cpu_mode: `host-passthrough`
- Provider: `libvirt` (not VirtualBox)
- Port forward: guest 8080 → host 8080 (bound to 127.0.0.1)
- Sync: rsync, excluding `.git/` and `.vagrant/`
- Bootstrap: `apt update && apt upgrade -y`, optional `id_rsa.pub` → `authorized_keys`, reboot

### Network helpers

`Vagrant-Scripts/` contains libvirt network setup helpers. If `vagrant up` fails with
network errors, run `start-vagrant-networks.sh` first.

### Known issues with the libvirt provider

- The VM reboots during provisioning (kernel update). Wait for the reboot to complete before
  running Ansible.
- If the default libvirt network is not started, use `start-networks.sh`.
- Use `cleanup-vagrant.sh` to fully destroy and remove all libvirt resources if the VM gets
  into a broken state.

---

## What remains to be done (from `CONFIG-ANALYSIS.md`)

### Phase 1 — In progress / pending

| Item | Status |
|---|---|
| Additional JDKs (Temurin 11, 17, 21) | ⚠ Not yet implemented in playbook |
| Multiple JDK versions in `JAVA_HOME` alternates | ⚠ Not yet implemented |
| Wazuh agent | ⚠ Optional — add when monitoring is required |
| InstallBuilder PATH entry | ⚠ Review if needed |

### Phase 2 — After new server has DNS/IP

| Item | Notes |
|---|---|
| Hostname + `/etc/hosts` | Configure with new server's IP |
| Nginx reverse proxy | Extract from production, update domains/certs |
| Backup mount | `//u158991.your-backup.de/backup` — new credentials needed |
| SSL certificates | Required for HTTPS reverse proxy |

### Phase 3 — After Jenkins is running

| Item | Notes |
|---|---|
| Cron: diskspace check | `08 08 * * * /home/jenkins/diskspace/rundiskspace` |
| Cron: queue depth log | Every 15 min |
| Root security cron | `0 5 * * 6 /root/apt-security.sh` |
| Monitoring integration | Nagios plugins already installed |

---

## Testing and validation

### Linting (run before every commit)

```bash
cd /path/to/infrastructure
yamllint .                    # ~2 seconds
ansible-lint --offline        # ~60 seconds
```

### Ansible syntax check

```bash
cd jenkins-as-code/ansible
ansible-playbook setup-jenkins-host.yml --syntax-check
ansible-playbook install-jenkins-server.yml --syntax-check
```

### Dry run

```bash
ansible-playbook -i inventory-vagrant.yml setup-jenkins-host.yml --check --diff
ansible-playbook -i inventory-vagrant.yml install-jenkins-server.yml --check --diff
```

### Selective role deployment

```bash
# Only security roles
ansible-playbook setup-jenkins-host.yml --tags security

# Only NTP
ansible-playbook setup-jenkins-host.yml --tags system

# Only Java installation
ansible-playbook setup-jenkins-host.yml --tags java

# Only Jenkins install and start
ansible-playbook install-jenkins-server.yml --tags jenkins_install,jenkins_start
```

---

## Commit message conventions

For changes to this sub-project, prefix commits:

- `jenkins-as-code:` — general changes to this sub-project
- `jenkins-as-code: ansible:` — playbook or role changes
- `jenkins-as-code: backup:` — backup/restore script changes
- `jenkins-as-code: vagrant:` — Vagrantfile or Vagrant-Scripts changes
- `jenkins-as-code: docs:` — documentation only

For cross-cutting infrastructure changes, follow the conventions in
[`.github/copilot-instructions.md`](../.github/copilot-instructions.md).

---

## Quick reference: key file paths

| Purpose | Path |
|---|---|
| All defaults | `jenkins-as-code/ansible/group_vars/all.yml` |
| Step 1 playbook | `jenkins-as-code/ansible/setup-jenkins-host.yml` |
| Step 2 playbook | `jenkins-as-code/ansible/install-jenkins-server.yml` |
| Prod inventory | `jenkins-as-code/ansible/inventory-production.yml` |
| Vagrant inventory | `jenkins-as-code/ansible/inventory-vagrant.yml` |
| systemd unit template | `jenkins-as-code/ansible/templates/jenkins.service.j2` |
| Jenkins defaults template | `jenkins-as-code/ansible/templates/jenkins-defaults.j2` |
| Backup script | `jenkins-as-code/jenkins-scripts/backup-jenkins-app-config.sh` |
| Restore script | `jenkins-as-code/jenkins-scripts/restore-jenkins-app-config.sh` |
| Restore overrides | `jenkins-as-code/jenkins-scripts/restore-config-overrides.env` |
| Vagrantfile | `jenkins-as-code/Vagrantfile` |

---

*Made with Bob*
