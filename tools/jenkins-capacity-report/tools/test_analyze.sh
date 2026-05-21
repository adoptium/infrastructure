#!/bin/bash
# Test the analyze function

analyze_clouds() {
    local file="$1"
    
    echo "Analyzing clouds configuration..."
    echo ""
    
    # Count cloud providers
    local orka_count=$(grep -c "io.jenkins.plugins.orka.OrkaCloud" "$file" 2>/dev/null || echo "0")
    local azure_count=$(grep -c "com.microsoft.azure.vmagent.AzureVMCloud" "$file" 2>/dev/null || echo "0")
    local aws_count=$(grep -c "hudson.plugins.ec2.EC2Cloud" "$file" 2>/dev/null || echo "0")
    local kubernetes_count=$(grep -c "org.csanchez.jenkins.plugins.kubernetes.KubernetesCloud" "$file" 2>/dev/null || echo "0")
    local docker_count=$(grep -c "com.nirima.jenkins.plugins.docker.DockerCloud" "$file" 2>/dev/null || echo "0")
    
    echo "Cloud Providers Found:"
    echo "======================"
    [ "$orka_count" -gt 0 ] && echo "  • Orka (MacStadium): $orka_count"
    [ "$azure_count" -gt 0 ] && echo "  • Azure: $azure_count"
    [ "$aws_count" -gt 0 ] && echo "  • AWS EC2: $aws_count"
    [ "$kubernetes_count" -gt 0 ] && echo "  • Kubernetes: $kubernetes_count"
    [ "$docker_count" -gt 0 ] && echo "  • Docker: $docker_count"
    
    local total_clouds=$((orka_count + azure_count + aws_count + kubernetes_count + docker_count))
    echo ""
    echo "Total Cloud Configurations: $total_clouds"
    echo ""
    
    # Count templates
    if [ "$orka_count" -gt 0 ]; then
        local orka_templates=$(grep -c "io.jenkins.plugins.orka.AgentTemplate" "$file" 2>/dev/null || echo "0")
        echo "  • Orka Templates: $orka_templates"
    fi
    
    if [ "$azure_count" -gt 0 ]; then
        local azure_templates=$(grep -c "com.microsoft.azure.vmagent.AzureVMAgentTemplate" "$file" 2>/dev/null || echo "0")
        echo "  • Azure Templates: $azure_templates"
    fi
}

analyze_clouds ../data/clouds.xml.live
