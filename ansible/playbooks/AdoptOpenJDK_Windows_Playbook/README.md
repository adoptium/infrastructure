# Setting up Windows Machines

There's a process to setting up Windows machines and getting them connected to Jenkins. If not followed, issues can occur with Jenkins workspaces (See: https://github.com/AdoptOpenJDK/openjdk-infrastructure/issues/1674).

1) Log on to the Windows machine via RDP and run the `ConfigureRemotingForAnsible` commands listed in [main.yml](https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Windows_Playbook/main.yml).

2) Run the playbook on the machine, without skipping the 'adoptopenjdk' and 'jenkins' tags. (See [this](https://github.com/AdoptOpenJDK/openjdk-infrastructure/blob/master/ansible/README.md) for more information).

3) Login to the Jenkins user on the machine via RDP.

4) On the machine, in a web browser, login to [ci.adoptopenjdk.net](https://ci.adoptopenjdk.net/), create a new node and download/run the `slave-agent.jnlp`. IcedTea-Web will need to be installed to run the `.jnlp` file.

5) Install the Jenkins agent as a service, by clicking 'File > Install as a Service'. This will require the Administrator credentials.

6) Ensure the Jenkins Agent starts as the Jenkins user, under the 'Properties/Log On` tab of the 'Jenkins agent' service.

7) If done correctly, under the `C:\Users\jenkins\` directory, there will be a series of `jenkins-slave.*` files, as well as the default Windows home folders, such as 'Desktop','Contacts' and 'Documents' etc.

8) Ensure you have signed out of ci.adoptopenjdk.net
