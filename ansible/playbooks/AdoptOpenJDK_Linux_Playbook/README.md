# AdoptOpenJDK - Ansible Playbook README.MD

## Platform Supported:

```
CentOS 7
- x86_64

RedHat 6
- x86_64
- ppc64

RedHat 7
- x86_64
- ppc64
- ppc64le
- s390x

SLES 11
- x86_64
- ppc64

SLES 12
- x86_64
- s390x

UB 14
- x86_64
- ppc64le

UB 16
- x86_64
- ppc64le
- s390x

Raspbian 8
- armv7l

Oracle Linux 7
- aarch64

FreeBSD 11
- x86_64
```

## Playbook Layout: (tree view)
```
.
├── README.md
├── group_vars
│   └── all
│       └── adoptopenjdk_variables.yml
├── main.retry
├── main.yml
└── roles
    ├── Ant-Contrib
    │   └── tasks
    │       └── main.yml
    ├── CPAN
    │   └── tasks
    │       └── main.yml
    ├── Clean_Up
    │   └── tasks
    │       └── main.yml
    ├── Common
    │   ├── tasks
    │   │   ├── CentOS.yml
    │   │   ├── OracleLinux.yml
    │   │   ├── RedHat.yml
    │   │   ├── SLES.yml
    │   │   ├── Ubuntu.yml
    │   │   ├── build_packages_and_tools.yml
    │   │   └── main.yml
    │   └── vars
    │       ├── CentOS.yml
    │       ├── OracleLinux.yml
    │       ├── RedHat.yml
    │       ├── SLES.yml
    │       └── Ubuntu.yml
    ├── Crontab
    │   └── tasks
    │       └── main.yml
    ├── Debug
    │   └── tasks
    │       └── main.yml
    ├── Docker
    │   └── tasks
    │       └── main.yml
    ├── GIT_Source
    │   └── tasks
    │       └── main.yml
    ├── Jenkins_User
    │   └── tasks
    │       └── main.yml
    ├── NTP_TIME
    │   └── tasks
    │       └── main.yml
    ├── NVidia_Cuda_Toolkit
    │   └── tasks
    │       └── main.yml
    ├── Nagios_Plugins
    │   └── tasks
    │       ├── main.yml
    │       ├── nagios_CentOS.yml
    │       ├── nagios_RedHat.yml
    │       ├── nagios_SLES.yml
    │       └── nagios_Ubuntu.yml
    ├── Superuser
    │   └── tasks
    │       └── main.yml
    ├── Swap_File
    │   └── tasks
    │       └── main.yml
    ├── Vendor
    │   └── tasks
    │       └── main.yml
    ├── ccache
    │   └── tasks
    │       └── main.yml
    ├── cmake
    │   └── tasks
    │       └── main.yml
    ├── gcc_48
    │   └── tasks
    │       └── main.yml
    └── x11
        └── tasks
            └── main.yml

42 directories, 38 files
```
