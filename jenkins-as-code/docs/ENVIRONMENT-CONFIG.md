# Environment-Based Configuration Guide

This guide explains how to deploy Jenkins with different configurations for production and development environments.

## Overview

The Jenkins installation playbook automatically detects system memory and adjusts heap size accordingly. You can also use environment-specific inventory files to override settings.

## Automatic Memory Detection

By default, the playbook automatically calculates appropriate heap size based on available system memory:

| System RAM | Jenkins Heap | Use Case |
|------------|--------------|----------|
| < 6GB      | 2G          | Small dev/test VMs |
| 6-14GB     | 4G          | Medium dev environments |
| 14-30GB    | 8G          | Staging environments |
| 30GB+      | 19G         | Production (matches current setup) |

## Deployment Methods

### Method 1: Auto-Detection (Recommended for Dev)

Let the playbook automatically detect and configure based on system resources:

```bash
# Uses auto-detection
ansible-playbook setup-jenkins-host.yml --connection=local
ansible-playbook install-jenkins-server.yml --connection=local
```

**Best for:** Vagrant VMs, development environments, testing

### Method 2: Environment-Specific Inventory (Recommended for Production)

Use pre-configured inventory files for consistent deployments:

#### Production Deployment

```bash
# Production with 19GB heap, localhost-only binding
ansible-playbook -i inventory-production.yml setup-jenkins-host.yml
ansible-playbook -i inventory-production.yml install-jenkins-server.yml
```

**Configuration:**
- Heap: 19GB (fixed)
- Listen: 127.0.0.1 (requires reverse proxy)
- Fail2ban: Production IP whitelist
- Environment: production

#### Vagrant/Development Deployment

```bash
# Development with auto-detected heap, all-interface binding
ansible-playbook -i inventory-vagrant.yml setup-jenkins-host.yml
ansible-playbook -i inventory-vagrant.yml install-jenkins-server.yml
```

**Configuration:**
- Heap: Auto-detected (2G/4G/8G based on VM RAM)
- Listen: 0.0.0.0 (direct access, no proxy needed)
- Fail2ban: Local network whitelist
- Environment: development

### Method 3: Environment Variables

Override specific settings using environment variables:

```bash
# Custom heap size
export JENKINS_HEAP_SIZE="8G"
ansible-playbook install-jenkins-server.yml --connection=local

# Custom listen address (for dev without proxy)
export JENKINS_LISTEN_ADDRESS="0.0.0.0"
ansible-playbook install-jenkins-server.yml --connection=local

# Both
export JENKINS_HEAP_SIZE="4G"
export JENKINS_LISTEN_ADDRESS="0.0.0.0"
ansible-playbook install-jenkins-server.yml --connection=local
```

### Method 4: Playbook Variables

Override in the playbook or via command line:

```bash
# Command line override
ansible-playbook install-jenkins-server.yml --connection=local \
  -e "jenkins_heap_size=8G" \
  -e "jenkins_listen_address=0.0.0.0"
```

## Configuration Comparison

### Production Configuration

```yaml
# inventory-production.yml
jenkins_heap_size: "19G"              # Fixed for production
jenkins_listen_address: "127.0.0.1"   # Reverse proxy required
fail2ban_ignoreip: "127.0.0.1/8 ::1 10.0.0.0/8 192.168.0.0/16 78.47.239.96 46.224.123.39 178.62.115.224 20.90.182.165"
```

**Use when:**
- Deploying to production servers
- System has 32GB+ RAM
- Using Nginx/Apache reverse proxy
- Need consistent, predictable configuration

### Vagrant/Development Configuration

```yaml
# inventory-vagrant.yml
jenkins_heap_size: "auto"             # Auto-detect based on VM RAM
jenkins_listen_address: "0.0.0.0"     # Direct access
fail2ban_ignoreip: "127.0.0.1/8 ::1 10.0.0.0/8 192.168.0.0/16 172.16.0.0/12"
```

**Use when:**
- Testing in Vagrant VMs
- Local development
- Limited system resources
- No reverse proxy setup

## Vagrant Integration

### Example Vagrantfile Configuration

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  
  # Small dev VM (4GB RAM) - will use 2G heap
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
    vb.cpus = 2
  end
  
  # Medium dev VM (8GB RAM) - will use 4G heap
  # config.vm.provider "virtualbox" do |vb|
  #   vb.memory = "8192"
  #   vb.cpus = 4
  # end
  
  # Provision with Ansible
  config.vm.provision "ansible_local" do |ansible|
    ansible.playbook = "ansible/setup-jenkins-host.yml"
    ansible.inventory_path = "ansible/inventory-vagrant.yml"
  end
  
  config.vm.provision "ansible_local" do |ansible|
    ansible.playbook = "ansible/install-jenkins-server.yml"
    ansible.inventory_path = "ansible/inventory-vagrant.yml"
  end
end
```

## Verification

After deployment, verify the configuration:

```bash
# Check heap size in use
ps aux | grep jenkins | grep Xmx

# Check listen address
sudo netstat -tlnp | grep 8080
# or
sudo ss -tlnp | grep 8080

# Check Jenkins configuration
sudo cat /etc/default/jenkins | grep JAVA_ARGS

# View systemd environment
sudo systemctl show jenkins | grep JENKINS_HOME
```

## Memory Sizing Guidelines

### Development/Testing

**4GB VM (2G heap):**
- Basic testing
- Small projects
- Limited concurrent builds

**8GB VM (4G heap):**
- Medium projects
- Multiple concurrent builds
- Plugin testing

### Staging

**16GB System (8G heap):**
- Pre-production testing
- Load testing
- Multiple concurrent builds

### Production

**32GB+ System (19G heap):**
- Large-scale deployments
- Many concurrent builds
- Extensive plugin usage
- Large test suites

## Troubleshooting

### Heap Size Too Large

**Symptom:** Jenkins fails to start, OOM errors

**Solution:**
```bash
# Check available memory
free -h

# Override with smaller heap
export JENKINS_HEAP_SIZE="4G"
ansible-playbook install-jenkins-server.yml --connection=local
```

### Can't Access Jenkins (127.0.0.1 binding)

**Symptom:** Can't access Jenkins from browser

**Solution for Dev:**
```bash
# Use vagrant inventory or override
export JENKINS_LISTEN_ADDRESS="0.0.0.0"
ansible-playbook install-jenkins-server.yml --connection=local
```

**Solution for Production:**
Set up reverse proxy (Nginx/Apache) - see JENKINS-INSTALL.md

### Auto-Detection Not Working

**Symptom:** Unexpected heap size

**Solution:**
```bash
# Check detected memory
ansible localhost -m setup -a 'filter=ansible_memtotal_mb'

# Override manually
ansible-playbook install-jenkins-server.yml --connection=local \
  -e "jenkins_heap_size=4G"
```

## Best Practices

1. **Production:** Always use `inventory-production.yml` with fixed heap size
2. **Development:** Use `inventory-vagrant.yml` with auto-detection
3. **Testing:** Test with production-like heap sizes before deploying
4. **Monitoring:** Monitor memory usage and adjust if needed
5. **Documentation:** Document any custom heap sizes in your inventory

## Examples

### Quick Dev Setup (4GB VM)

```bash
cd jenkins-as-code/ansible
ansible-playbook -i inventory-vagrant.yml setup-jenkins-host.yml
ansible-playbook -i inventory-vagrant.yml install-jenkins-server.yml
# Result: 2G heap, accessible on 0.0.0.0:8080
```

### Production Deployment (32GB+ Server)

```bash
cd jenkins-as-code/ansible
ansible-playbook -i inventory-production.yml setup-jenkins-host.yml
ansible-playbook -i inventory-production.yml install-jenkins-server.yml
# Result: 19G heap, accessible on 127.0.0.1:8080 (needs reverse proxy)
```

### Custom Staging Setup (16GB Server)

```bash
cd jenkins-as-code/ansible
ansible-playbook setup-jenkins-host.yml --connection=local \
  -e "jenkins_heap_size=8G" \
  -e "jenkins_listen_address=127.0.0.1"
ansible-playbook install-jenkins-server.yml --connection=local \
  -e "jenkins_heap_size=8G" \
  -e "jenkins_listen_address=127.0.0.1"
# Result: 8G heap, accessible on 127.0.0.1:8080
```

---

**Made with Bob**