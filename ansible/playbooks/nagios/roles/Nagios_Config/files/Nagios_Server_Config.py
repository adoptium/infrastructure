## Define Template And Host Mappings

templates = {'build_win': 'build-windows-template.j2',
            'test_win': 'test-windows-template.j2',
            'build_macos': 'build-macos-template.j2',
            'test_macos': 'test-macos-template.j2',
            'build_aix': 'build-aix-template.j2',
            'test_aix': 'test-aix-template.j2',
            'build_centos': 'build-centos-template.j2',
            'test_centos': 'test-centos-template.j2',
            'build_ubuntu': 'build-ubuntu-template.j2',
            'test_ubuntu': 'test-ubuntu-template.j2',
            'build_rhel': 'build-rhel-template.j2',
            'test_rhel': 'test-rhel-template.j2',
            'build_sles': 'build-sles-template.j2',
            'test_sles': 'test-sles-template.j2',
            'dockerhost_ubuntu': 'dockerhost-ubuntu-template.j2'}

## Define Any Hosts That Should Have Specialist Mappings
## Any Hosts With Entries In This Section, Will OverRide The Default Checks
## Mapping Is Done On A Per-Host Basis

special_templates = {'test-equinix_esxi-solaris10-x64-1': 'test-solaris-noport-template.j2',
            'test-siteox-solaris10u11-sparcv9-1': 'test-solaris-port-template.j2',
            'build-equinix_esxi-solaris10-x64-1': 'test-solaris-noport-template.j2',
            'build-siteox-solaris10u11-sparcv9-1': 'test-solaris-port-template.j2'}

## Define Any Hosts That Should Be Excluded

excluded_hosts = {'build-spearhead-freebsd12-x64-1',
                  'test-inspira-solaris10u11-sparcv9-1',
                  'build-inspira-solaris10u11-sparcv9-1',
                  'build-inspira-solaris10u11-sparcv9-2'}
