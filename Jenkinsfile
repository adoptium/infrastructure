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
    def git_sha = "${env.GIT_COMMIT.trim()}"
    dockerImage = docker.build("adoptopenjdk/${distro}_build_image:linux-${architecture}",
        "--build-arg git_sha=$git_sha -f ansible/docker/$dockerfile .")
    // dockerhub is the ID of the credentials stored in Jenkins 
    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
        dockerImage.push()
    }

    // Push to GitHub Packages
    def ghRepo = "adoptium/infrastructure"
    def ghPackageTag = "docker.pkg.github.com/${ghRepo}/${distro}_build_image:linux-${architecture}"

    dockerImage.tag(ghPackageTag)
    docker.withRegistry('https://docker.pkg.github.com', 'eclipse_temurin_bot_token') {
        dockerImage.push(ghPackageTag)
    }
}

def dockerManifest() { 
    // dockerhub is the ID of the credentials stored in Jenkins
    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
        processManifest('https://github.com/adoptium/infrastructure.git')
    }

    docker.withRegistry('https://docker.pkg.github.com', 'eclipse_temurin_bot_token') {
        processManifest('https://github.com/adoptium/infrastructure.git', 'docker.pkg.github.com/adoptium/infrastructure/')
    }
}

def processManifest(gitUrl, registryPrefix='') {
    git poll: false, url: gitUrl
    sh '''
        # Add function to process each image manifest
        createAndPushManifest() {
            export TARGET="${1}${2}"
            docker manifest create $TARGET "$@"
            shift
            shift
            for IMAGE in "$@"; do
                ARCH=$(echo $IMAGE | rev | cut -d- -f1 | rev)
                docker manifest annotate $TARGET $IMAGE --arch $ARCH --os linux
            done
            docker manifest push $TARGET
        }
        # Centos7
        createAndPushManifest "${registryPrefix}" "adoptopenjdk/centos7_build_image" \
            "adoptopenjdk/centos7_build_image:linux-amd64" \
            "adoptopenjdk/centos7_build_image:linux-arm64" \
            "adoptopenjdk/centos7_build_image:linux-ppc64le"
        # Ubuntu1604
        createAndPushManifest "${registryPrefix}" "adoptopenjdk/ubuntu1604_build_image" \
            "adoptopenjdk/ubuntu1604_build_image:linux-armv7l"
        # Alpine3
        createAndPushManifest "${registryPrefix}" "adoptopenjdk/alpine3_build_image" \
            "adoptopenjdk/alpine3_build_image:linux-amd64" \
            "adoptopenjdk/alpine3_build_image:linux-arm64"
    '''
}
