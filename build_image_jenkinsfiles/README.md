# Adoptium Build Image Updater Jenkinsfiles

This directory contains the Jenkins pipelines responsible for building and publishing the Adoptium build images used by the project for building JDKs, and pushing them to the [AdoptOpenJDK Docker Hub](https://hub.docker.com/u/adoptopenjdk).

The corresponding Jenkins jobs can be viewed in the Jenkins folder: [Adoptium_Build_Image_Updater](https://ci.adoptium.net/job/Adoptium_Build_Image_Updater/).

## Pipelines

* **[`Jenkinsfile.parent`](Jenkinsfile.parent)**: High-level orchestrator pipeline that triggers the downstream child build jobs in parallel across the various platforms and distros, followed by the manifest publication job.
* **[`Jenkinsfile.child`](Jenkinsfile.child)**: Parameterized worker pipeline that builds and pushes individual Docker build images on the designated builder agent.
* **[`Jenkinsfile.manifest`](Jenkinsfile.manifest)**: Standalone pipeline that creates, annotates, and pushes the multi-architecture Docker manifest lists to Docker Hub.
