#!/bin/bash
################################################################################
# Script: extract_clouds_config.sh
# Description: Extract clouds configuration from Jenkins config.xml
# Usage: Run this script on the Jenkins controller
# Author: Bob
# Date: 2026-02-17
################################################################################

set -e  # Exit on error

# Configuration
JENKINS_HOME="${JENKINS_HOME:-/home/jenkins/.jenkins}"
CONFIG_FILE="${JENKINS_HOME}/config.xml"
OUTPUT_FILE="${OUTPUT_FILE:-clouds.xml}"
ANALYZE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to analyze clouds configuration
analyze_clouds() {
    local file="$1"
    
    print_info "Analyzing clouds configuration..."
    echo ""
    
    # Count cloud providers (using grep -c which returns a single number)
    local orka_count=$(grep -c "io.jenkins.plugins.orka.OrkaCloud" "$file" 2>/dev/null || echo "0")
    local azure_count=$(grep -c "com.microsoft.azure.vmagent.AzureVMCloud" "$file" 2>/dev/null || echo "0")
    local aws_count=$(grep -c "hudson.plugins.ec2.EC2Cloud" "$file" 2>/dev/null || echo "0")
    local kubernetes_count=$(grep -c "org.csanchez.jenkins.plugins.kubernetes.KubernetesCloud" "$file" 2>/dev/null || echo "0")
    local docker_count=$(grep -c "com.nirima.jenkins.plugins.docker.DockerCloud" "$file" 2>/dev/null || echo "0")
    
    # Remove any whitespace/newlines
    orka_count=$(echo "$orka_count" | tr -d '[:space:]')
    azure_count=$(echo "$azure_count" | tr -d '[:space:]')
    aws_count=$(echo "$aws_count" | tr -d '[:space:]')
    kubernetes_count=$(echo "$kubernetes_count" | tr -d '[:space:]')
    docker_count=$(echo "$docker_count" | tr -d '[:space:]')
    
    echo "Cloud Providers Found:"
    echo "======================"
    [ "$orka_count" != "0" ] && echo "  • Orka (MacStadium): $orka_count"
    [ "$azure_count" != "0" ] && echo "  • Azure: $azure_count"
    [ "$aws_count" != "0" ] && echo "  • AWS EC2: $aws_count"
    [ "$kubernetes_count" != "0" ] && echo "  • Kubernetes: $kubernetes_count"
    [ "$docker_count" != "0" ] && echo "  • Docker: $docker_count"
    
    local total_clouds=$((orka_count + azure_count + aws_count + kubernetes_count + docker_count))
    echo ""
    echo "Total Cloud Configurations: $total_clouds"
    echo ""
    
    # Count templates
    if [ "$orka_count" != "0" ]; then
        local orka_templates=$(grep -c "io.jenkins.plugins.orka.AgentTemplate" "$file" 2>/dev/null || echo "0")
        orka_templates=$(echo "$orka_templates" | tr -d '[:space:]')
        echo "  • Orka Templates: $orka_templates"
    fi
    
    if [ "$azure_count" != "0" ]; then
        local azure_templates=$(grep -c "com.microsoft.azure.vmagent.AzureVMAgentTemplate" "$file" 2>/dev/null || echo "0")
        azure_templates=$(echo "$azure_templates" | tr -d '[:space:]')
        echo "  • Azure Templates: $azure_templates"
    fi
    
    if [ "$aws_count" != "0" ]; then
        local aws_templates=$(grep -c "hudson.plugins.ec2.SlaveTemplate" "$file" 2>/dev/null || echo "0")
        aws_templates=$(echo "$aws_templates" | tr -d '[:space:]')
        echo "  • AWS Templates: $aws_templates"
    fi
    
    if [ "$kubernetes_count" != "0" ]; then
        local k8s_templates=$(grep -c "org.csanchez.jenkins.plugins.kubernetes.PodTemplate" "$file" 2>/dev/null || echo "0")
        k8s_templates=$(echo "$k8s_templates" | tr -d '[:space:]')
        echo "  • Kubernetes Pod Templates: $k8s_templates"
    fi
    
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--analyze)
            ANALYZE=true
            shift
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Extract clouds configuration from Jenkins config.xml"
            echo ""
            echo "Options:"
            echo "  -a, --analyze          Analyze the extracted configuration"
            echo "  -o, --output FILE      Specify output file (default: clouds.xml)"
            echo "  -h, --help             Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  JENKINS_HOME          Jenkins home directory (default: /home/jenkins/.jenkins)"
            echo "  OUTPUT_FILE           Output file name (default: clouds.xml)"
            echo ""
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Check if running on Jenkins controller
print_info "Checking Jenkins environment..."

# Check if config.xml exists
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Jenkins config.xml not found at: $CONFIG_FILE"
    print_info "Please set JENKINS_HOME environment variable or run this script on the Jenkins controller"
    exit 1
fi

print_info "Found Jenkins config.xml at: $CONFIG_FILE"

# Extract clouds configuration
print_info "Extracting clouds configuration..."

if sed -n '/<clouds>/,/<\/clouds>/p' "$CONFIG_FILE" > "$OUTPUT_FILE"; then
    # Check if the output file has content
    if [ -s "$OUTPUT_FILE" ]; then
        print_info "Successfully extracted clouds configuration to: $OUTPUT_FILE"
        
        # Display file size and line count
        FILE_SIZE=$(wc -c < "$OUTPUT_FILE")
        LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
        
        print_info "File size: $FILE_SIZE bytes"
        print_info "Line count: $LINE_COUNT lines"
        
        # Show first few lines as preview
        print_info "Preview (first 10 lines):"
        echo "----------------------------------------"
        head -n 10 "$OUTPUT_FILE"
        echo "----------------------------------------"
        
        # Analyze if requested
        if [ "$ANALYZE" = true ]; then
            echo ""
            analyze_clouds "$OUTPUT_FILE"
        fi
        
    else
        print_warning "No clouds configuration found in config.xml"
        print_info "The Jenkins instance may not have any cloud configurations defined"
        rm -f "$OUTPUT_FILE"
        exit 0
    fi
else
    print_error "Failed to extract clouds configuration"
    exit 1
fi

print_info "Extraction complete!"
print_info "Output file: $(pwd)/$OUTPUT_FILE"

if [ "$ANALYZE" = false ]; then
    echo ""
    print_info "Tip: Use -a or --analyze flag to analyze the configuration"
fi

# Made with Bob
