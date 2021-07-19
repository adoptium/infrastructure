# Setting up Windows Machines

There's a process to setting up Windows machines and getting them connected to Jenkins. If not followed, issues can occur with Jenkins workspaces (See: https://github.com/adoptium/infrastructure/issues/1674).

1) Log on to the Windows machine via RDP and run the `ConfigureRemotingForAnsible` commands listed in [main.yml](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Windows_Playbook/main.yml).

Note: If setting up a win2012r2 machine, `[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12` needs to be executed to stop `Invoke-WebRequest` encountering a `Could not create SSL/TLS secure channel` error. See: https://github.com/adoptium/infrastructure/issues/1858

2) Run the playbook on the machine, without skipping the 'adoptopenjdk' and 'jenkins' tags. (See [this](https://github.com/adoptium/infrastructure/blob/master/ansible/README.md) for more information).

3) Login to the Jenkins user on the machine via RDP.

4) On the machine, in a web browser, login to [ci.adoptopenjdk.net](https://ci.adoptopenjdk.net/), create a new node and download/run the `slave-agent.jnlp`. [IcedTea-Web](https://adoptopenjdk.net/icedtea-web.html) (or another `javaws` implementation) will need to be installed to run the `.jnlp` file.

5) Install the Jenkins agent as a service, by clicking 'File > Install as a Service'. This will require the Administrator credentials.

6) Ensure the Jenkins Agent starts as the Jenkins user, under the 'Properties/Log On` tab of the 'Jenkins agent' service.

7) If done correctly, under the `C:\Users\jenkins\` directory, there will be a series of `jenkins-slave.*` files, as well as the default Windows home folders, such as 'Desktop','Contacts' and 'Documents' etc.

8) Ensure you have signed out of ci.adoptopenjdk.net
