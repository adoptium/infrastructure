# AdoptOpenJDK - Ansible AIX Playbook README.MD

## AIX OS levels Supported:

```
7100-04 # 01-1543
7100-05 # 06-2028
7200-02
7200-04
```

The configuration scripts should work from 7100-02 - and other
AIX 7.2 TL levels, but these are the TL levels tested (i.e., supported)


## Playbook Layout: (tree view) : WIP (work in progress)
aix == .
```
aix
aix/group_vars
aix/roles
aix/roles/fs
aix/roles/oss
aix/roles/verify
```
