# Setting up Windows Machines

There's a process to setting up Windows machines and getting them connected to Jenkins. If not followed, issues can occur with Jenkins workspaces (See: https://github.com/adoptium/infrastructure/issues/1674).

1) Log on to the Windows machine via RDP and run the `ConfigureRemotingForAnsible` commands listed in [main.yml](https://github.com/adoptium/infrastructure/blob/master/ansible/playbooks/AdoptOpenJDK_Windows_Playbook/main.yml).

Note: If setting up a win2012r2 machine, `[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12` needs to be executed to stop `Invoke-WebRequest` encountering a `Could not create SSL/TLS secure channel` error. See: https://github.com/adoptium/infrastructure/issues/1858

2) Run the playbook on the machine, without skipping the 'adoptopenjdk' and 'jenkins' tags. (See [this](https://github.com/adoptium/infrastructure/blob/master/ansible/README.md) for more information).

3) Login as the Jenkins user on the machine via RDP, and ensure access can be gained, and create 2 directories, one for the jenkins workspace ( typically called workspace, and a parallel directory called agent.

4) On any machine, in a web browser, login to [ci.adoptium.net](https://ci.adoptium.net/), create a new node ( best done as a copy of an existing node ), but ensure the launch option is set to "Launch Agent By Connecting It To A Controller"

5) Login as the administrator user on the machine via RDP, and download the relevant [WinSW - Windows Service Wrapper](https://github.com/winsw/winsw/releases/) executable for the platform, e.g [WinSW-x64.exe](https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW-x64.exe)  and copy the downloaded file to the agent directory created in step 3.

6) In the created agent directory, rename the file downloaded in step 5) from WinSW-x64.exe to something meaningful, e.g. JenkinsAgentService.exe

7) Create an accompanying XML file in the agent directory, and give it the same name as the renamed executable, but with an xml file extension, e.g JenkinsAgentService.xml.

8) Now edit the xml file and populate the file in a similar fashion to the below, the key , edit the fields from the example shown below as appropriate:
   - **id** :  This should be set to a unique name for the windows service
   - **name** : This should be set to a descriptive name, and will be the name of the service displayed on the screen in windows
   - **description** : This should be set to a meaningful description
   - **executable** : This should be set to the full path to the  java executable, that will be used to run the jenkins agent.
   - **arguments** This can be obtained from the node configuration page in Jenkins, the *xxxxxx* should reflect the name of the node being created in jenkins, and the *yyyyyyyy* string will be an encoded hex string, used for passing the jenkins user password
   - **download from** the URL here should be changed to match the jenkins server name, from which the service can download the agent.jar

	All other fields can be left as in the example.

>     <service>
>       <id>Jenkins</id>
>       <name>Jenkins</name>
>      <description>This service runs an agent for Jenkins automation server.</description>
>      <executable>C:\openjdk\jdk-17\bin\java.exe</executable>
>      <arguments>-Xrs -jar "%BASE%\agent.jar" -jnlpUrl https://ci.adoptium.net/computer/xxxxxxxxxx/jenkins-agent.jnlp -secret yyyyyyyyyyyyy -workDir=F:\workspace</arguments>
>      <logmode>rotate</logmode>
>      <onfailure action="restart" />
>        <download from="https://ci.adoptium.net/jnlpJars/agent.jar" to="%BASE%\agent.jar"/>
>      </service>

9)  As the windows administrator, open an elevated command prompt, and now create the Jenkins agent service by following this process :

	 - cd to the agent directory ( where the executable and xml file are stored )
	 - run the executable with a parameter install (e.g **.\JenkinsAgentService.exe INSTALL**)
 
	 You should get confirmation prompts on screen that the service has been created.
	 
	- Next open the windows services dialog, and identify the Jenkins service that has just been created. Right click on the service and select **Start** from the pop up menu.
	
The jenkins service should then be started.

