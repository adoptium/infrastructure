# Production Jenkins Configuration Notes

This document details the production Jenkins configuration settings used in the `install-jenkins-server.yml` playbook, based on the adoptium/infrastructure Jenkins master.

## Configuration Source

These settings are extracted from the production Jenkins master at Hetzner running Ubuntu 20.04, and have been adapted for Ubuntu 24.04 deployment.

## Key Configuration Settings

### Jenkins Home Directory

```bash
JENKINS_HOME=/home/jenkins/.jenkins
```

**Rationale:** Mirrors production setup. This differs from the default `/var/lib/jenkins` to keep all Jenkins data under the jenkins user's home directory for easier management and backup.

### JVM Memory Settings

```bash
JAVA_ARGS="-Xmx19G ..."
```

**Current Setting:** 19GB maximum heap
**System Requirement:** 32GB+ RAM recommended

**History of Memory Tuning:**
1. Initial: `-Xmx20g -Xms8g`
2. Added GC tuning: `-Xmx16g -Xms8g` with G1GC and detailed logging
3. Increased to `-Xmx18G` (2023-01-09, issue #2875)
4. Further tuned to `-Xmx20G` with G1GC optimizations
5. Adjusted to `-Xmx22G` with XStream limits
6. **Current:** `-Xmx19G` (2026-05-28, issue #4364) with JUnit optimizations

**Recommendation for Different System Sizes:**
- 4GB RAM: `-Xmx2G`
- 8GB RAM: `-Xmx4G`
- 16GB RAM: `-Xmx8G`
- 32GB+ RAM: `-Xmx19G` (production)

### JUnit Memory Optimizations

```bash
-Dhudson.tasks.junit.TestResultAction.RESULT_CACHE_ENABLED=false
-Dhudson.tasks.junit.History\$HistoryTableResult.PREVIOUS_TEST_RESULT_BACKTRACK_BUILDS_MAX=1
```

**Added:** 2026-05-28 by sxa & aleonard
**Issue:** https://github.com/adoptium/infrastructure/issues/4364
**Purpose:** Reduce memory consumption from JUnit test result caching

### GC Logging Configuration

```bash
-Xlog:gc*,gc+heap=info,gc+age=trace,gc+phases=trace,safepoint:file=/var/log/jenkins/gc.log:time,uptime,level,tags:filecount=5,filesize=50m
```

**Features:**
- Detailed GC logging with heap info, age tracking, and phase details
- Rotating log files: 5 files × 50MB each = 250MB total
- Includes timestamps and log levels
- Logs safepoint information for performance analysis

**Log Location:** `/var/log/jenkins/gc.log`

### XStream Security

```bash
-Dhudson.util.XStream2.collectionUpdateLimit=-1
```

**Purpose:** Removes the default limit on XStream collection updates
**Caution:** This is a security-related setting. The default limit prevents potential DoS attacks via large XML payloads. Set to -1 only if you trust all XML sources.

### Network Configuration

```bash
JENKINS_ARGS="... --httpListenAddress=127.0.0.1"
```

**Setting:** Listen on localhost only (127.0.0.1)
**Rationale:** Jenkins should be accessed through a reverse proxy (Nginx/Apache) with HTTPS
**Security:** Prevents direct external access to Jenkins

### Session Management

```bash
--sessionTimeout=720 --sessionEviction=43200
```

**Session Timeout:** 720 minutes (12 hours)
**Session Eviction:** 43,200 seconds (12 hours)

**Added by:** Martijn (2019-03-21) and sxa (2024-05-09)
**Purpose:** Balance security with user convenience for long-running operations

### Access Logging

```bash
--accessLoggerClassName=winstone.accesslog.SimpleAccessLogger
--simpleAccessLogger.format=combined
--simpleAccessLogger.file=/var/log/jenkins/access.log
```

**Added by:** Martijn (2019-03-21)
**Format:** Combined log format (Apache-style)
**Location:** `/var/log/jenkins/access.log`
**Purpose:** Audit trail and troubleshooting

### File Descriptor Limits

```bash
MAXOPENFILES=8192
```

**Setting:** 8,192 open files
**Rationale:** Jenkins can have many concurrent connections and file operations
**Note:** Also set in systemd service override (`LimitNOFILE=8192`)

### Java Location

```bash
JAVA=/usr/lib/jvm/temurin-25-jdk-amd64/bin/java
```

**JDK:** Eclipse Temurin 25 (Adoptium)
**Architecture:** amd64
**Source:** Adoptium APT repository

## Directory Structure

```
/home/jenkins/.jenkins/          # Jenkins home (JENKINS_HOME)
├── config.xml                   # Main Jenkins configuration
├── plugins/                     # Installed plugins
├── jobs/                        # Job configurations
├── workspace/                   # Build workspaces
├── updates/                     # Update center data
├── secrets/                     # Secrets and credentials
│   └── initialAdminPassword     # Initial setup password
└── logs/                        # Jenkins internal logs

/var/cache/jenkins/              # Jenkins cache
└── war/                         # Exploded WAR files

/var/log/jenkins/                # Jenkins logs
├── jenkins.log                  # Main application log
├── access.log                   # HTTP access log
└── gc.log                       # Garbage collection log
```

## Security Considerations

### 1. Localhost-Only Binding

Jenkins listens only on 127.0.0.1, requiring a reverse proxy for external access. This provides:
- HTTPS termination at the proxy
- Additional security layer
- Better logging and monitoring
- DDoS protection

### 2. File Permissions

```bash
# UMASK not set (defaults to 022)
# Sensitive files (credentials) always written with restricted permissions
```

### 3. Systemd Security

```ini
NoNewPrivileges=true    # Prevents privilege escalation
PrivateTmp=true         # Isolated /tmp directory
```

## Performance Tuning Notes

### Memory Allocation Strategy

The production system uses 19GB heap on a 32GB+ RAM system, leaving approximately:
- 10-12GB for OS and other processes
- 2-3GB for file system cache
- Headroom for memory spikes

### GC Strategy

Using default G1GC (Java 9+) with:
- Detailed logging for performance analysis
- Rotating logs to prevent disk space issues
- Safepoint logging for identifying pause causes

### JUnit Optimization

Disabling JUnit result caching significantly reduces memory usage for projects with extensive test suites, at the cost of slightly slower test result page loads.

## Monitoring Recommendations

### 1. GC Logs

Monitor `/var/log/jenkins/gc.log` for:
- Long GC pauses (>1 second)
- Frequent full GCs
- Heap exhaustion warnings

### 2. Access Logs

Monitor `/var/log/jenkins/access.log` for:
- Unusual access patterns
- Failed authentication attempts
- Performance issues (slow requests)

### 3. System Resources

Monitor:
- Memory usage (should stay below 90% of allocated heap)
- CPU usage during builds
- Disk I/O for workspace operations
- Network throughput

## Upgrade Considerations

When upgrading Jenkins or Java:

1. **Backup First:** Always backup `/home/jenkins/.jenkins/` before upgrades
2. **Test GC Settings:** New Java versions may have different GC defaults
3. **Review Logs:** Check GC logs after upgrade for performance changes
4. **Monitor Memory:** Watch for memory leaks or increased usage
5. **Plugin Compatibility:** Verify all plugins work with new Jenkins version

## References

- [Adoptium Infrastructure Issue #2875](https://github.com/adoptium/infrastructure/issues/2875) - Memory increase to 18G
- [Adoptium Infrastructure Issue #4364](https://github.com/adoptium/infrastructure/issues/4364) - JUnit memory optimizations
- [Jenkins Performance Tuning](https://www.jenkins.io/doc/book/scaling/hardware-recommendations/)
- [G1GC Tuning Guide](https://docs.oracle.com/en/java/javase/17/gctuning/garbage-first-g1-garbage-collector1.html)

---

**Last Updated:** 2026-06-25
**Based on:** Production Jenkins master configuration (Ubuntu 20.04)
**Target:** Ubuntu 24.04 deployment

**Made with Bob**