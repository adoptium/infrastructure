# Windows 11 Arctic Agent Configuration

This directory contains automation scripts and documentation for configuring Windows 11 virtual machines (ARM64 and x64) with an interactive console desktop environment in Session 1 for [Corretto Arctic](https://github.com/corretto/arctic) GUI testing and Jenkins CI/CD integration.

The tooling is divided into two distinct approaches based on VM lifecycle and infrastructure design:

---

## Workflows and Subfolders

### 1. Dynamic Provisioning (`dynamic-vm/`)
- **Location**: [`dynamic-vm/`](dynamic-vm/README.md)
- **Target Use Case**: Automated, on-demand, and ephemeral Jenkins agents dynamically provisioned in Azure using the Jenkins Azure VM Agents plugin.
- **What It Achieves**:
  - Prepares a baseline Windows 11 virtual machine (`image-prep.ps1`) before sysprep and image capture into an Azure Compute Gallery.
  - Configures automated Winlogon recovery across sysprep and Azure VM provisioning cycles.
  - Automatically attaches new instances to Jenkins at launch using the template Initialization script (`jenkins-inbound-init.ps1`), launching the agent directly into interactive console Session 1.
  - Applies a clean, uniform desktop layout (black background, hidden taskbar, hidden icons, closed notifications) on every dynamically spawned VM.

### 2. Static / Standalone Provisioning (`static-vm/`)
- **Location**: [`static-vm/`](static-vm/README.md)
- **Target Use Case**: Dedicated, persistent, or manually managed Windows 11 virtual machines (such as static test lab nodes, on-premise Hyper-V VMs, or local test machines).
- **What It Achieves**:
  - Provides a single, all-in-one configuration script (`standalone-vm-setup.ps1`) for newly created standalone VMs without requiring custom images or sysprep generalization.
  - Configures Winlogon auto-logon for an existing local user account directly to console Session 1 upon boot.
  - Optionally connects the machine as a persistent Jenkins inbound agent (`agent.jar` TCP inbound connection).
  - Supplies modular utilities (`configure-agent-desktop.ps1`) for fine-grained desktop adjustments, display resolution setting, and remote session management (`tscon` RDP-to-console handover).

---

## Directory Layout

| Folder / File | Role | Purpose |
|---|---|---|
| [`dynamic-vm/`](dynamic-vm/README.md) | Dynamic Agents | Custom image preparation and dynamic Jenkins template scripts |
| [`static-vm/`](static-vm/README.md) | Static Agents | Standalone VM setup, manual configuration, and desktop utilities |
| [`PLAN.md`](PLAN.md) | Architecture & History | Background rationale, investigation history, design rules, and status |

---

## Documentation Links

- **[Dynamic VM Provisioning Guide](dynamic-vm/README.md)**: Full instructions for building gallery images, sysprep, and Jenkins agent template settings.
- **[Static VM Configuration Guide](static-vm/README.md)**: Full instructions for running setup scripts on standalone machines, parameter reference, verification, and troubleshooting.
- **[Architecture & Investigation History](PLAN.md)**: Details on why console Session 1 is required, trials conducted, and core design rules.
