# Jenkins Integration Guide

This guide explains how to integrate the Azure Windows Image Updater with Jenkins for automated, parameterized image updates.

## Overview

The workflow supports Jenkins integration through parameterized builds, allowing you to:

- Select which image(s) to update via Jenkins parameters
- Schedule automated updates (e.g., monthly)
- Track update history through Jenkins build logs
- Integrate with existing CI/CD pipelines

## Architecture

```
Jenkins Pipeline
    ↓
Parameter: IMAGE_NAME (choice)
    ↓
SSH to azureupdater user
    ↓
Run workflow for selected image
    ↓
Capture new image version
    ↓
Report results back to Jenkins
```

## Prerequisites

### 1. Dedicated User Setup

The workflow should run as a dedicated user (e.g., `azureupdater`):

```bash
# On the Jenkins agent/node, run as root:
sudo ./setup-dedicated-user.sh
```

This creates:
- User: `azureupdater`
- Home: `/home/azureupdater`
- Project: `/home/azureupdater/azure-image-updater`
- Authentication: SSH key only (no password)

### 2. SSH Key Configuration

Add the Jenkins SSH credentials:

1. Generate SSH key pair (if not exists):
   ```bash
   ssh-keygen -t rsa -b 4096 -C "jenkins-azure-updater"
   ```

2. Add public key to authorized_keys:
   ```bash
   sudo nano /home/azureupdater/.ssh/authorized_keys
   # Paste the public key
   ```

3. Add private key to Jenkins:
   - Navigate to: Jenkins → Credentials → System → Global credentials
   - Add Credentials → SSH Username with private key
   - ID: `azure-image-updater-ssh`
   - Username: `azureupdater`
   - Private Key: Paste the private key

### 3. Azure Credentials

Store Azure credentials in Jenkins:

1. **Subscription ID** (Secret text)
   - ID: `azure-subscription-id`
   - Value: Your Azure subscription ID

2. **Tenant ID** (Secret text)
   - ID: `azure-tenant-id`
   - Value: Your Azure AD tenant ID

3. **Client ID** (Secret text)
   - ID: `azure-client-id`
   - Value: Service principal client ID

4. **Client Secret** (Secret text)
   - ID: `azure-client-secret`
   - Value: Service principal client secret

## Jenkins Pipeline Configuration

### Option 1: Declarative Pipeline (Recommended)

Create a new Pipeline job with this Jenkinsfile:

```groovy
pipeline {
    agent {
        label 'azure-updater-node'  // Node with azureupdater user
    }
    
    parameters {
        choice(
            name: 'IMAGE_NAME',
            choices: [
                'Test-Windows-2025-x64',
                'Test-Windows-2022-x64',
                'Test-Windows-11-x64'
            ],
            description: 'Select the Windows image to update'
        )
        booleanParam(
            name: 'DRY_RUN',
            defaultValue: false,
            description: 'Perform a dry run without capturing the image'
        )
    }
    
    environment {
        AZURE_SUBSCRIPTION_ID = credentials('azure-subscription-id')
        AZURE_TENANT_ID = credentials('azure-tenant-id')
        AZURE_CLIENT_ID = credentials('azure-client-id')
        AZURE_CLIENT_SECRET = credentials('azure-client-secret')
        PROJECT_DIR = '/home/azureupdater/azure-image-updater'
    }
    
    stages {
        stage('Validate Configuration') {
            steps {
                script {
                    echo "Selected Image: ${params.IMAGE_NAME}"
                    echo "Dry Run: ${params.DRY_RUN}"
                    
                    sh '''
                        cd $PROJECT_DIR
                        source .env
                        ./scripts/0-check-prerequisites.sh
                    '''
                }
            }
        }
        
        stage('Provision VM') {
            steps {
                script {
                    sh '''
                        cd $PROJECT_DIR
                        export AZURE_IMAGE_DEFINITION="${IMAGE_NAME}"
                        export AZURE_SOURCE_IMAGE="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Compute/galleries/${AZURE_GALLERY_NAME}/images/${IMAGE_NAME}"
                        source .env
                        ./scripts/1-provision-vm.sh
                    '''
                }
            }
        }
        
        stage('Configure WinRM') {
            steps {
                script {
                    sh '''
                        cd $PROJECT_DIR
                        source .env
                        ./scripts/3-configure-winrm.sh
                    '''
                }
            }
        }
        
        stage('Test Ansible') {
            steps {
                script {
                    sh '''
                        cd $PROJECT_DIR
                        source .env
                        ./scripts/4-test-ansible.sh
                    '''
                }
            }
        }
        
        stage('Run Windows Updates') {
            steps {
                script {
                    sh '''
                        cd $PROJECT_DIR
                        source .env
                        ./scripts/5-run-updates.sh
                    '''
                }
            }
        }
        
        stage('Sysprep VM') {
            steps {
                script {
                    sh '''
                        cd $PROJECT_DIR
                        source .env
                        ./scripts/6-run-sysprep.sh
                    '''
                }
            }
        }
        
        stage('Validate VM Ready') {
            steps {
                script {
                    sh '''
                        cd $PROJECT_DIR
                        source .env
                        ./scripts/7-validate-vm-ready.sh
                    '''
                }
            }
        }
        
        stage('Capture Image') {
            when {
                expression { params.DRY_RUN == false }
            }
            steps {
                script {
                    sh '''
                        cd $PROJECT_DIR
                        export AZURE_IMAGE_DEFINITION="${IMAGE_NAME}"
                        source .env
                        ./scripts/8-capture-image.sh
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                // Archive logs
                archiveArtifacts artifacts: 'logs/**/*.log', allowEmptyArchive: true
                
                // Cleanup (optional - remove temporary resources)
                sh '''
                    cd $PROJECT_DIR
                    source .env
                    # Add cleanup script if needed
                '''
            }
        }
        success {
            echo "Image ${params.IMAGE_NAME} updated successfully!"
        }
        failure {
            echo "Failed to update image ${params.IMAGE_NAME}"
        }
    }
}
```

### Option 2: Scripted Pipeline

```groovy
node('azure-updater-node') {
    def imageName = params.IMAGE_NAME
    def projectDir = '/home/azureupdater/azure-image-updater'
    
    withCredentials([
        string(credentialsId: 'azure-subscription-id', variable: 'AZURE_SUBSCRIPTION_ID'),
        string(credentialsId: 'azure-tenant-id', variable: 'AZURE_TENANT_ID'),
        string(credentialsId: 'azure-client-id', variable: 'AZURE_CLIENT_ID'),
        string(credentialsId: 'azure-client-secret', variable: 'AZURE_CLIENT_SECRET')
    ]) {
        stage('Update Image') {
            sh """
                cd ${projectDir}
                export AZURE_IMAGE_DEFINITION="${imageName}"
                export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}"
                export AZURE_TENANT_ID="${AZURE_TENANT_ID}"
                export AZURE_CLIENT_ID="${AZURE_CLIENT_ID}"
                export AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET}"
                source .env
                ./scripts/test-full-workflow.sh
            """
        }
    }
}
```

## Pipeline Parameters

### IMAGE_NAME (Choice Parameter)

**Type**: Choice Parameter  
**Name**: `IMAGE_NAME`  
**Choices**:
```
Test-Windows-2025-x64
Test-Windows-2022-x64
Test-Windows-11-x64
```

**Description**: Select the Windows image to update

**To Add More Images**:
1. Create the image definition in Azure Compute Gallery
2. Add to the choices list in Jenkinsfile
3. Update `.env` file on the Jenkins node

### DRY_RUN (Boolean Parameter)

**Type**: Boolean Parameter  
**Name**: `DRY_RUN`  
**Default**: `false`  
**Description**: Perform a dry run without capturing the image

Useful for:
- Testing the workflow
- Validating changes before capture
- Troubleshooting issues

## Scheduling

### Monthly Updates

Add a cron trigger to run on the first Sunday of each month at 2 AM:

```groovy
pipeline {
    triggers {
        // Run at 2 AM on the first Sunday of each month
        cron('0 2 1-7 * 0')
    }
    // ... rest of pipeline
}
```

### Custom Schedule Examples

```groovy
// Every Sunday at 2 AM
cron('0 2 * * 0')

// First day of every month at 3 AM
cron('0 3 1 * *')

// Every Saturday at midnight
cron('0 0 * * 6')

// Twice a month (1st and 15th at 2 AM)
cron('0 2 1,15 * *')
```

## Multi-Image Pipeline

To update all images in sequence:

```groovy
pipeline {
    agent {
        label 'azure-updater-node'
    }
    
    parameters {
        booleanParam(
            name: 'UPDATE_ALL',
            defaultValue: false,
            description: 'Update all images (ignores IMAGE_NAME selection)'
        )
        choice(
            name: 'IMAGE_NAME',
            choices: [
                'Test-Windows-2025-x64',
                'Test-Windows-2022-x64',
                'Test-Windows-11-x64'
            ],
            description: 'Select single image (used when UPDATE_ALL is false)'
        )
    }
    
    stages {
        stage('Update Images') {
            steps {
                script {
                    def projectDir = '/home/azureupdater/azure-image-updater'
                    
                    if (params.UPDATE_ALL) {
                        echo "Updating all images..."
                        sh """
                            cd ${projectDir}
                            source .env
                            ./scripts/run-all-images.sh
                        """
                    } else {
                        echo "Updating single image: ${params.IMAGE_NAME}"
                        sh """
                            cd ${projectDir}
                            export AZURE_IMAGE_DEFINITION="${params.IMAGE_NAME}"
                            source .env
                            ./scripts/test-full-workflow.sh
                        """
                    }
                }
            }
        }
    }
}
```

## Notifications

### Email Notifications

Add to `post` section:

```groovy
post {
    success {
        emailext(
            subject: "✓ Image Update Success: ${params.IMAGE_NAME}",
            body: """
                Image ${params.IMAGE_NAME} has been successfully updated.
                
                Build: ${env.BUILD_URL}
                Duration: ${currentBuild.durationString}
            """,
            to: 'team@example.com'
        )
    }
    failure {
        emailext(
            subject: "✗ Image Update Failed: ${params.IMAGE_NAME}",
            body: """
                Failed to update image ${params.IMAGE_NAME}.
                
                Build: ${env.BUILD_URL}
                Console: ${env.BUILD_URL}console
            """,
            to: 'team@example.com'
        )
    }
}
```

### Slack Notifications

```groovy
post {
    success {
        slackSend(
            color: 'good',
            message: "✓ Image ${params.IMAGE_NAME} updated successfully\nBuild: ${env.BUILD_URL}"
        )
    }
    failure {
        slackSend(
            color: 'danger',
            message: "✗ Failed to update image ${params.IMAGE_NAME}\nBuild: ${env.BUILD_URL}"
        )
    }
}
```

## Monitoring and Logs

### Jenkins Build Logs

All script output is captured in Jenkins console output:
- Navigate to build → Console Output
- Search for specific stages or errors
- Download full log for offline analysis

### Archived Artifacts

Configure artifact archiving:

```groovy
post {
    always {
        archiveArtifacts artifacts: 'logs/**/*.log', allowEmptyArchive: true
    }
}
```

Access archived logs:
- Build page → Build Artifacts
- Download individual log files
- Compare logs across builds

## Troubleshooting

### SSH Connection Issues

**Problem**: Jenkins cannot SSH to azureupdater user

**Solutions**:
1. Verify SSH key is added to authorized_keys
2. Check SSH key permissions (600 for private key)
3. Test SSH manually: `ssh azureupdater@hostname`
4. Check Jenkins SSH credentials configuration

### Azure Authentication Fails

**Problem**: Azure CLI commands fail with authentication errors

**Solutions**:
1. Verify Azure credentials in Jenkins
2. Check service principal has correct permissions
3. Test authentication manually:
   ```bash
   az login --service-principal \
       -u $AZURE_CLIENT_ID \
       -p $AZURE_CLIENT_SECRET \
       --tenant $AZURE_TENANT_ID
   ```

### Image Not Found

**Problem**: Image definition not found in gallery

**Solutions**:
1. Verify image name matches exactly (case-sensitive)
2. Check image exists in gallery:
   ```bash
   az sig image-definition show \
       --resource-group adoptopenjdk \
       --gallery-name adoptium_compute_gallery \
       --gallery-image-definition Test-Windows-2022-x64
   ```
3. Create missing image definition

### Build Timeout

**Problem**: Build times out during Windows Updates

**Solutions**:
1. Increase Jenkins build timeout
2. Split into multiple stages with longer timeouts
3. Consider running updates during off-peak hours

## Best Practices

### 1. Use Dedicated Jenkins Node

Create a dedicated Jenkins node for image updates:
- Label: `azure-updater-node`
- Ensures consistent environment
- Isolates long-running builds

### 2. Schedule During Off-Hours

Run updates when:
- Jenkins load is low
- Azure resources are available
- Team can monitor if needed

### 3. Test with Dry Run First

Before production updates:
1. Run with `DRY_RUN=true`
2. Verify all steps complete
3. Check logs for warnings
4. Then run actual capture

### 4. Version Control Jenkinsfile

Store Jenkinsfile in repository:
- Track changes over time
- Review before deployment
- Rollback if needed

### 5. Monitor Build History

Regularly review:
- Build duration trends
- Failure patterns
- Resource usage

## Security Considerations

### 1. Credential Management

- Store all secrets in Jenkins credentials
- Never hardcode credentials in Jenkinsfile
- Rotate credentials regularly
- Use least-privilege service principals

### 2. Access Control

- Restrict who can trigger builds
- Use Jenkins RBAC for parameter changes
- Audit build history
- Monitor for unauthorized access

### 3. Network Security

- Use private networks where possible
- Restrict NSG rules to necessary ports
- Consider VPN for Jenkins-Azure communication
- Enable Azure Private Link if available

## Extending the Pipeline

### Add Pre-Update Validation

```groovy
stage('Pre-Update Validation') {
    steps {
        script {
            // Check if image is in use
            sh '''
                # Query VMs using this image
                # Notify if image is actively used
            '''
        }
    }
}
```

### Add Post-Update Testing

```groovy
stage('Test New Image') {
    steps {
        script {
            // Deploy test VM from new image
            // Run validation tests
            // Clean up test VM
        }
    }
}
```

### Add Rollback Capability

```groovy
stage('Rollback on Failure') {
    when {
        expression { currentBuild.result == 'FAILURE' }
    }
    steps {
        script {
            // Delete failed image version
            // Restore previous version as latest
        }
    }
}
```

## Summary

The Jenkins integration provides:

✅ **Parameterized Builds**: Select which image to update  
✅ **Scheduled Updates**: Automate monthly updates  
✅ **Centralized Logging**: All logs in Jenkins  
✅ **Notifications**: Email/Slack alerts  
✅ **Audit Trail**: Complete build history  
✅ **Scalability**: Easy to add more images  

## Next Steps

1. Set up dedicated user on Jenkins node
2. Configure SSH credentials in Jenkins
3. Add Azure credentials to Jenkins
4. Create Jenkins pipeline job
5. Test with dry run
6. Schedule regular updates
7. Monitor and refine

---

**Made with Bob** 🤖