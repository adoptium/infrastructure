# Setting up Standard Windows Machines

There's a process to setting up Windows machines and getting them connected to Jenkins. If not followed, issues can occur with Jenkins workspaces (See: https://github.com/adoptium/infrastructure/issues/1674).

1. Log on to the Windows machine via RDP and run the `ConfigureRemotingForAnsible` commands listed in [main.yml](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Windows_Playbook/main.yml).

Note: If setting up a win2012r2 machine, `[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12` needs to be executed to stop `Invoke-WebRequest` encountering a `Could not create SSL/TLS secure channel` error. See: https://github.com/adoptium/infrastructure/issues/1858

1. Run the playbook on the machine, without skipping the 'adoptopenjdk' and 'jenkins' tags. (See [this](https://github.com/adoptium/infrastructure/blob/master/ansible/README.md) for more information).

1. Login as the Jenkins user on the machine via RDP, and ensure access can be gained, and create 2 directories, one for the jenkins workspace ( typically called workspace, and a parallel directory called agent.

1. On any machine, in a web browser, login to [ci.adoptium.net](https://ci.adoptium.net/), create a new node ( best done as a copy of an existing node ), but ensure the launch option is set to "Launch Agent By Connecting It To A Controller"

1. Jenkins service creation is now automated by the [Jenkins_Service_Installation](./roles/Jenkins_Service_Installation/) role which automatically creates the relevant config files and installs [WIN-SW](https://github.com/winsw/winsw). In order to take advantage of this role you must first set a variable called `jenkins_secret` which is set to the secret JNLP string defined in Jenkins when you create the new node. This can be done in one of two ways:

    1. Add the machine to the secrets repo config file in `secrets/vendor_files/Jenkins_Secrets.yml.gpg`. Simply add a new line using the following schema, commit and push:

    ```yaml
    <hostname>: <secret>
    ```

    2. Set the variable manually in the [adoptopenjdk_variables.yml](./group_vars/all/adoptopenjdk_variables.yml) file.

Note that the role will be skipped if it cannot find a `jenkins_secret` variable. The role will also not remove any previosuly created service using the previous JNLP process.

The jenkins service should then be started.

# Setting up Windows Dockerhost Machines

There are a number of prerequisite steps, and preparation steps required when building a windows dockerhost machine. The user the playbooks execute has needs to have administrative permissions in order to have docker install and execute correctly.

1. Log on to the Windows machine via RDP and run the `ConfigureRemotingForAnsible` commands listed in [main.yml](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Windows_Playbook/windows_dockerhost.yml).

1. Prerequisite Configuration Required For A Windows Docker Host

The target machine must support docker for windows ( by utilising the containers )
windows feature, and also windows Hyper-V support. These do not have to be enabled, as
this playbook will enable them, however if unsure, please perform these steps manually
as enabling this features on machines that do not support them can cause issues.

For Windows docker dosts the base machine MUST have a 2nd disk to be used
exclusively for the docker data, the drive letter for this must be configured
in the group_vars/all/docker_variables.yml.

A recommended size of at least 150Gb for the docker data drive.

# Running The Windows Dockerhost playbook

Before running the windows docker host playbook [windows_dockerhost.yml](./windows_dockerhost.yml), a few variables need to be configured in the in the [docker_variables.yml](./group_vars/all/docker_variables.yml) file.

Specifically these values should be set :

ansible_password: ( The password used to connect to the machine )
docker_data_drive: ( This should be set to the drive letter for the preconfigured empty docker data drive )
jenkins_secret: ( This should be set to the jenkins secret used for connecting the agent to jenkins )

Once all the above is complete, the playbook can then be run:

ansible-playbook -i << path to hosts file >> -u << target user name >> ./windows_dockerhost.yml
