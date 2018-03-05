# AdoptOpenJDK - Ansible Playbook README.MD

## Platform Supported:

```
CentOS 6
- x86_64

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
├── group_vars
│   └── all
│       └── adoptopenjdk_variables.yml
├── main.yml
├── README.md
└── roles
    ├── Ant-Contrib
    │   └── tasks
    │       └── main.yml
    ├── ccache
    │   └── tasks
    │       └── main.yml
    ├── Clean_Up
    │   └── tasks
    │       └── main.yml
    ├── cmake
    │   └── tasks
    │       └── main.yml
    ├── Common
    │   ├── tasks
    │   │   ├── build_packages_and_tools.yml
    │   │   ├── CentOS.yml
    │   │   ├── FreeBSD.yml
    │   │   ├── main.yml
    │   │   ├── OracleLinux.yml
    │   │   ├── RedHat.yml
    │   │   ├── SLES.yml
    │   │   └── Ubuntu.yml
    │   └── vars
    │       ├── CentOS.yml
    │       ├── FreeBSD.yml
    │       ├── OracleLinux.yml
    │       ├── RedHat.yml
    │       ├── SLES.yml
    │       └── Ubuntu.yml
    ├── CPAN
    │   └── tasks
    │       └── main.yml
    ├── Crontab
    │   └── tasks
    │       └── main.yml
    ├── Debug
    │   └── tasks
    │       └── main.yml
    ├── Docker
    │   └── tasks
    │       └── main.yml
    ├── gcc_48
    │   └── tasks
    │       └── main.yml
    ├── GIT_Source
    │   └── tasks
    │       └── main.yml
    ├── Jenkins_User
    │   └── tasks
    │       └── main.yml
    ├── Nagios_Master_Config
    │   └── tasks
    │       └── main.yml
    ├── Nagios_Plugins
    │   └── tasks
    │       ├── additional_plugins
    │       │   ├── check_pkg
    │       │   ├── check_sw_up
    │       │   ├── check_yum
    │       │   └── check_zypper
    │       ├── main.yml
    │       ├── nagios_CentOS.yml
    │       ├── nagios_FreeBSD.yml
    │       ├── nagios_RedHat.yml
    │       ├── nagios_SLES.yml
    │       └── nagios_Ubuntu.yml
    ├── NTP_TIME
    │   └── tasks
    │       └── main.yml
    ├── NVidia_Cuda_Toolkit
    │   └── tasks
    │       └── main.yml
    ├── Security
    │   └── tasks
    │       └── main.yml
    ├── Superuser
    │   └── tasks
    │       └── main.yml
    ├── Swap_File
    │   └── tasks
    │       └── main.yml
    ├── Vendor
    │   └── tasks
    │       └── main.yml
    └── x11
        └── tasks
            └── main.yml

47 directories, 46 files
```
