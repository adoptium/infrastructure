#!/bin/bash -x

JENKINS_URL='http://localhost:8080'
NODE_NAME=$1
NODE_IP=$2
NODE_SLAVE_HOME=$3
EXECUTORS=1
SSH_PORT=22
CRED_ID='b8101a03-36e8-4687-a722-d48ad48acd5c'
LABELS=`echo $4 | tr ',' ' '`
USERID='jenkins'
JDK7=$5
JDK8=$6
JDK9=$7

cat <<EOF | java -jar ~/bin/jenkins-cli.jar -s ${JENKINS_URL} -ssh -user admin create-node ${NODE_NAME}
<slave>
  <name>${NODE_NAME}</name>
  <description></description>
  <remoteFS>${NODE_SLAVE_HOME}</remoteFS>
  <numExecutors>${EXECUTORS}</numExecutors>
  <mode>NORMAL</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy$Always"/>
  <launcher class="hudson.plugins.sshslaves.SSHLauncher" plugin="ssh-slaves@1.5">
    <host>${NODE_IP}</host>
    <port>${SSH_PORT}</port>
    <credentialsId>${CRED_ID}</credentialsId>
  </launcher>
  <label>${LABELS}</label>
  <nodeProperties>
    <hudson.slaves.EnvironmentVariablesNodeProperty>
      <envVars serialization="custom">
        <unserializable-parents/>
        <tree-map>
          <default>
            <comparator class="hudson.util.CaseInsensitiveComparator"/>
          </default>
          <int>3</int>
          <string>JDK7_BOOT_DIR</string>
          <string>${JDK7}</string>
          <string>JDK8_BOOT_DIR</string>
          <string>${JDK8}</string>
          <string>JDK9_BOOT_DIR</string>
          <string>${JDK9}</string>
        </tree-map>
      </envVars>
    </hudson.slaves.EnvironmentVariablesNodeProperty>
  </nodeProperties>
  <userId>${USERID}</userId>
</slave>
EOF
