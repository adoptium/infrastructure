pipeline {
    agent none
    stages {
        stage('Docker Build') {
            parallel { 
                stage('CentOS7 x64') {
                    agent {
                        label "dockerBuild&&linux&&x64"
                    } 
                    steps {
                        dockerBuild('amd64', 'centos7', 'Dockerfile.CentOS7')
                    }
                }
                stage('CentOS7 aarch64') {
                    agent {
                        label "dockerBuild&&linux&&aarch64"
                    }
                    steps {
                        dockerBuild('arm64', 'centos7', 'Dockerfile.CentOS7')
                    }
                }
                stage('CentOS7 ppc64le') {
                    agent {
                        label "dockerBuild&&linux&&ppc64le"
                    }
                    steps {
                        dockerBuild('ppc64le', 'centos7', 'Dockerfile.CentOS7')
                    }
                }
                stage('Ubuntu16.04 armv7l') {
                    agent {
                        label "docker&&linux&&armv7l"
                    }
                    steps {
                        dockerBuild('armv7l', 'ubuntu1604', 'Dockerfile.Ubuntu1604')
                    }
                }
                stage('Alpine3 x64') {
                    agent {
                        label "dockerBuild&&linux&&x64"
                    }
                    steps {
                        dockerBuild('amd64', 'alpine3', 'Dockerfile.Alpine3')
                    }
                }
                stage('Alpine3 aarch64') {
                    agent {
                        label "dockerBuild&&linux&&aarch64"
                    }
                    steps {
                        dockerBuild('arm64', 'alpine3', 'Dockerfile.Alpine3')
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

def dockerBuild(architecture, distro, dockerfile) {
    git poll: false, url: 'https://github.com/adoptium/infrastructure.git'
    dockerImage = docker.build("adoptopenjdk/${distro}_build_image:linux-$architecture",
        "-f ansible/docker/$dockerfile .")
    // dockerhub is the ID of the credentials stored in Jenkins 
    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
        dockerImage.push()
    }
}

def dockerManifest() { 
    // dockerhub is the ID of the credentials stored in Jenkins
    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
        git poll: false, url: 'https://github.com/adoptium/infrastructure.git'
        sh '''
            # Centos7
            export TARGET="adoptopenjdk/centos7_build_image"
            AMD64=$TARGET:linux-amd64
            ARM64=$TARGET:linux-arm64
            PPC64LE=$TARGET:linux-ppc64le
            docker manifest create $TARGET $AMD64 $ARM64 $PPC64LE
            docker manifest annotate $TARGET $AMD64 --arch amd64 --os linux
            docker manifest annotate $TARGET $ARM64 --arch arm64 --os linux
            docker manifest annotate $TARGET $PPC64LE --arch ppc64le --os linux
            docker manifest push $TARGET
            # Ubuntu1604
            export TARGET="adoptopenjdk/ubuntu1604_build_image"
            ARMV7L=$TARGET:linux-armv7l
            docker manifest create $TARGET $ARMV7L
            docker manifest annotate $TARGET $ARMV7L --arch arm --os linux
            docker manifest push $TARGET
            # Alpine3
            export TARGET="adoptopenjdk/alpine3_build_image"
            AMD64=$TARGET:linux-amd64
            ARM64=$TARGET:linux-arm64
            docker manifest create $TARGET $AMD64 $ARM64
            docker manifest annotate $TARGET $AMD64 --arch amd64 --os linux
            docker manifest annotate $TARGET $ARM64 --arch arm64 --os linux
            docker manifest push $TARGET
        '''
    }
}
