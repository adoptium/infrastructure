pipeline {
    agent none
    stages {
        stage('Docker Build') {
            parallel { 
                stage('Linux x64') {
                    agent {
                        label "dockerBuild&&linux&&x64"
                    } 
                    steps {
                        dockerBuild('amd64')
                    }
                }
                stage('Linux aarch64') {
                    agent {
                        label "dockerBuild&&linux&&aarch64"
                    }
                    steps {
                        dockerBuild('arm64')
                    }
                }
                stage('Linux ppc64le') {
                    agent {
                        label "dockerBuild&&linux&&ppc64le"
                    }
                    steps {
                        dockerBuild('ppc64le')
                    }
                }
            }
        }
        stage('Docker Manifest') {
            agent {
                label "dockerBuild&&linux&&x64"
            } 
            environment {
                DOCKER_CLI_EXPERIMENTAL = "enabled"
            }
            steps {
                dockerManifest()
            }
        }
    } 
} 

def dockerBuild(architecture) {
    // dockerhub is the ID of the credentials stored in Jenkins 
    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
        git poll: false, url: 'https://github.com/adoptium/infrastructure.git'
        sh label: '', script: "docker build -t adoptopenjdk/centos7_build_image:linux-$architecture -f ansible/Dockerfile.CentOS7 ."
        sh label: '', script: "docker push adoptopenjdk/centos7_build_image:linux-$architecture
    }
}

def dockerManifest() { 
    // dockerhub is the ID of the credentials stored in Jenkins
    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
        git poll: false, url: 'https://github.com/adoptium/infrastructure.git'
        sh '''
            export TARGET="adoptopenjdk/centos7_build_image"
            AMD64=$TARGET:linux-amd64
            ARM64=$TARGET:linux-arm64
            PPC64LE=$TARGET:linux-ppc64le
            docker manifest create $TARGET $AMD64 $ARM64 $PPC64LE
            docker manifest annotate $TARGET $AMD64 --arch amd64 --os linux
            docker manifest annotate $TARGET $ARM64 --arch arm64 --os linux
            docker manifest annotate $TARGET $PPC64LE --arch ppc64le --os linux
            docker manifest push $TARGET
        '''
    }
}
