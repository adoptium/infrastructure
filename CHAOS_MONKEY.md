# Can we Chaos Monkey it?

A goal for the project is to be able to tear down any of our build or test hosts 
and recreate it completely from our Ansible playbooks.

## Security and Patching

Ansible must ensure that the underlying O/S is patched as well as any firewalls, 
VPN and other security configured before making the host available.

## Core Infrastructure

Provider | Host | role | Chaos Monkey? | Issue(s) |
|---|---|---|---|---|
| digitalocean | ubuntu1604-x64-1 | api.adoptopenjdk.net | No | TBA |
| packet | ubuntu1604-x64-1 | ansible.adoptopenjdk.net | No | TBA |
| softlayer | ubuntu1604-x64-3 | jckservices.adoptopenjdk.net | No | TBA |

## Build Hosts

|Provider | Host | Chaos Monkey? | Issue(s) |
|---|---|---|---|
| azure | win2008r2-x64-1 | No | TBA |
| cloudcone | ubuntu1604-x64-1 | No | TBA |
| digitalocean | centos69-x64-1 | No | TBA |
| linaro | centos74-armv8-1 | No | TBA |
| linaro | centos74-armv8-2 | No | TBA |
| macstadium | macos1010-x64-1 | No | TBA |
| macstadium | macos1010-x64-2 | No | TBA |
| marist | rhel74-s390x-1 | No | TBA |
| marist | rhel74-s390x-2 | No | TBA |
| marist | ubuntu1604-s390x-2 | No | TBA |
| marist | ubuntu1604-s390x-3 | No | TBA |
| marist | zos21-s390x-1 | No | TBA |
| marist | zos21-s390x-2 | No | TBA |
| osuosl | centos74-ppc64le-1 | No | TBA |
| osuosl | centos74-ppc64le-2 | No | TBA |
| osuosl | ubuntu1604-ppc64le-1 | No | TBA |
| osuosl | aix71-ppc64-1 | No | TBA |
| osuosl | aix71-ppc64-2 | No | TBA |
| packet | centos74-armv8-1 | No | TBA |
| packet | ubuntu1604-armv8-2 | No | TBA |
| joyent | centos69-x64-1 | No | TBA |
| scaleway | ubuntu1604-x64-2 | No | TBA |
| scaleway | ubuntu1604-armv7-1 | No | TBA |
| scaleway | ubuntu1604-armv7-2 | No | TBA |
| softlayer | win2012r2-x64-1 | No | TBA |
| softlayer | win2012r2-x64-2 | No | TBA |

## Test Hosts

|Provider | Host | Chaos Monkey? | Issue(s) |
|---|---|---|---|
| azure | win2012r2-x64-1 | No | TBA |
| macincloud | macos1010-x64-1 | No | TBA |
| macincloud | macos1010-x64-2 | No | TBA |
| marist | ubuntu1604-s390x-1 | No | TBA |
| osuosl | ubuntu1604-ppc64le-1 | No | TBA |
| osuosl | ubuntu1604-ppc64le-2 | No | TBA |
| packet | ubuntu1604-armv8-1 | No | TBA |
| packet | ubuntu1604-x64-1 | No | TBA |
| packet | ubuntu1604-x64-2 | No | TBA |
| packet | ubuntu1604-x64-3 | No | TBA |
| packet | win2012r2-x64-1 | No | TBA |
| scaleway | ubuntu1604-x64-1 | No | TBA |
| softlayer | ubuntu1604-x64-1 | No | TBA |
| softlayer | rhel74-x64-1 | No | TBA |
| softlayer | rhel69-x64-1 | No | TBA |
| softlayer | win2012r2-x64-1 | No | TBA |
