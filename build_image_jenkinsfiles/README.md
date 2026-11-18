# Build Image Jenkins Pipelines

This directory contains the modular Jenkins pipelines used to build and publish the Adoptium build images across multiple architectures and Linux distributions.

---

## Architecture Overview

Instead of running all Docker builds and manifest commands within a single monolithic pipeline on one node, the process is decoupled into an orchestrator (parent job), distributed builder jobs (child jobs), and a standalone manifest publication job:

```mermaid
flowchart TD
    Parent[build-image-parent<br/>Jenkinsfile.parent]

    subgraph Build Phase [Parallel Child Builds]
        C1[build-image-child<br/>CentOS6 x64]
        C2[build-image-child<br/>CentOS7 x64]
        C3[build-image-child<br/>CentOS7 aarch64]
        C4[build-image-child<br/>CentOS7 ppc64le]
        C5[build-image-child<br/>Ubuntu16.04 armv7l]
        C6[build-image-child<br/>Ubuntu20.04 riscv64]
        C7[build-image-child<br/>Alpine3 x64]
        C8[build-image-child<br/>Alpine3 aarch64]
    end

    Manifest[build-image-manifest<br/>Jenkinsfile.manifest]

    Parent -->|triggers in parallel| Build Phase
    Build Phase -->|after builds complete| Manifest
```

---

## Files

| File | Purpose | Jenkins Job Name |
| :--- | :--- | :--- |
| [`Jenkinsfile.parent`](Jenkinsfile.parent) | Orchestrator pipeline that kicks off child jobs in parallel and triggers the manifest job. | `build-image-parent` |
| [`Jenkinsfile.child`](Jenkinsfile.child) | Parameterized worker pipeline executed on target builder nodes to build and push individual Docker images. | `build-image-child` |
| [`Jenkinsfile.manifest`](Jenkinsfile.manifest) | Dedicated pipeline to create, annotate, and push multi-architecture Docker manifest lists to Docker Hub. | `build-image-manifest` |

---

## Pipeline Details

### 1. Parent Pipeline (`Jenkinsfile.parent`)
* **Role:** High-level coordinator.
* **Execution:**
  1. Spawns 8 parallel downstream builds of `build-image-child` passing the required parameters (`ARCHITECTURE`, `DISTRO`, `DOCKERFILE`, `NODE_LABEL`, `IS_ARM32`).
  2. Uses `catchError(buildResult: 'FAILURE', stageResult: 'FAILURE')` on each branch so that an isolated failure on one platform does not cancel remaining platforms or abort the pipeline before the manifest step.
  3. Triggers the final downstream `build-image-manifest` job.

### 2. Child Pipeline (`Jenkinsfile.child`)
* **Role:** Parameterized image builder.
* **Features:**
  * Dynamically schedules onto the required agent via `params.NODE_LABEL`.
  * Dynamically formats its build display name in the Jenkins UI (e.g. `#12 - centos7 (arm64)`).
  * Executes `docker buildx build` for standard architectures or `dockerBuildArm32` for 32-bit ARM targets.
* **Parameters:**
  * `ARCHITECTURE`: Target architecture (e.g. `amd64`, `arm64`, `ppc64le`, `riscv64`, `armv7l`).
  * `DISTRO`: Linux distribution name (e.g. `centos6`, `centos7`, `ubuntu1604`, `ubuntu2004`, `alpine3`).
  * `DOCKERFILE`: Name of the Dockerfile under `ansible/docker/`.
  * `NODE_LABEL`: Jenkins agent label expression (e.g. `dockerBuild&&linux&&x64&&containerBuilder`).
  * `IS_ARM32`: Boolean flag indicating if the target is an ARM32/armv7l build.

### 3. Manifest Pipeline (`Jenkinsfile.manifest`)
* **Role:** Multi-architecture manifest assembler and publisher.
* **Features:**
  * Runs independently so it can be re-executed or tested on demand without triggering full image rebuilds.
  * Creates, annotates, and pushes multi-architecture manifest lists on Docker Hub for:
    * `adoptopenjdk/centos6_build_image` (`linux-amd64`)
    * `adoptopenjdk/centos7_build_image` (`linux-amd64`, `linux-arm64`, `linux-ppc64le`)
    * `adoptopenjdk/ubuntu1604_build_image` (`linux-armv7l`)
    * `adoptopenjdk/alpine3_build_image` (`linux-amd64`, `linux-arm64`)
* **Parameters:**
  * `NODE_LABEL`: Jenkins agent label expression (default: `dockerBuild&&linux&&x64`).

---

## Jenkins Setup Guide

When configuring these jobs in the Jenkins UI:

1. **Create the Child Job (`build-image-child`):**
   * **Job Type:** Pipeline
   * **Definition:** Pipeline script from SCM $\rightarrow$ Git
   * **Repository:** `https://github.com/adoptium/infrastructure.git`
   * **Script Path:** `build_image_jenkinsfiles/Jenkinsfile.child`
   * *Run this job manually once* to register its declarative parameter definitions in Jenkins.

2. **Create the Manifest Job (`build-image-manifest`):**
   * **Job Type:** Pipeline
   * **Definition:** Pipeline script from SCM $\rightarrow$ Git
   * **Repository:** `https://github.com/adoptium/infrastructure.git`
   * **Script Path:** `build_image_jenkinsfiles/Jenkinsfile.manifest`
   * *Run this job manually once* to register its parameter definition.

3. **Create the Parent Job (`build-image-parent`):**
   * **Job Type:** Pipeline
   * **Definition:** Pipeline script from SCM $\rightarrow$ Git
   * **Repository:** `https://github.com/adoptium/infrastructure.git`
   * **Script Path:** `build_image_jenkinsfiles/Jenkinsfile.parent`
