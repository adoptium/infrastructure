#!/bin/bash
set -e

# Automated Multi-Image Workflow - No Prompts
# This script processes multiple images from AZURE_IMAGE_MULTIPLE (comma-separated)
# Runs the full workflow for each image automatically with cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Load environment variables
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${RED}ERROR: .env file not found at $PROJECT_ROOT/.env${NC}"
    echo "Please create it from .env.template"
    exit 1
fi

source "$PROJECT_ROOT/.env"

# Validate required variables
if [ -z "$AZURE_IMAGE_MULTIPLE" ]; then
    echo -e "${RED}ERROR: AZURE_IMAGE_MULTIPLE not set in .env${NC}"
    echo "Please set AZURE_IMAGE_MULTIPLE with comma-separated image names"
    exit 1
fi

if [ -z "$AZURE_GALLERY_NAME" ]; then
    echo -e "${RED}ERROR: AZURE_GALLERY_NAME not set in .env${NC}"
    exit 1
fi

if [ -z "$AZURE_RESOURCE_GROUP" ]; then
    echo -e "${RED}ERROR: AZURE_RESOURCE_GROUP not set in .env${NC}"
    exit 1
fi

# Parse image list (comma-separated)
IFS=',' read -ra IMAGE_LIST <<< "$AZURE_IMAGE_MULTIPLE"
IMAGE_COUNT=${#IMAGE_LIST[@]}

# Trim whitespace from each image name
for i in "${!IMAGE_LIST[@]}"; do
    IMAGE_LIST[$i]=$(echo "${IMAGE_LIST[$i]}" | xargs)
done

echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  Azure Windows Image Updater - Multi-Image Workflow   ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Gallery: $AZURE_GALLERY_NAME"
echo "  Resource Group: $AZURE_RESOURCE_GROUP"
echo "  Images to Process: $IMAGE_COUNT"
echo ""
echo -e "${YELLOW}Images:${NC}"
for img in "${IMAGE_LIST[@]}"; do
    echo "  - $img"
done
echo ""

# Get gallery resource group (defaults to VM resource group if not specified)
GALLERY_RG="${AZURE_GALLERY_RESOURCE_GROUP:-$AZURE_RESOURCE_GROUP}"

# Validate gallery exists
echo -e "${BLUE}Validating Azure Compute Gallery...${NC}"
if ! az sig show \
    --resource-group "$GALLERY_RG" \
    --gallery-name "$AZURE_GALLERY_NAME" \
    --output none 2>/dev/null; then
    echo -e "${RED}ERROR: Gallery '$AZURE_GALLERY_NAME' not found in resource group '$GALLERY_RG'${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Gallery exists${NC}"
echo ""

# Validate all images exist in gallery
echo -e "${BLUE}Validating image definitions...${NC}"
VALIDATION_FAILED=false
for IMAGE_NAME in "${IMAGE_LIST[@]}"; do
    echo -n "  Checking $IMAGE_NAME... "
    if az sig image-definition show \
        --resource-group "$GALLERY_RG" \
        --gallery-name "$AZURE_GALLERY_NAME" \
        --gallery-image-definition "$IMAGE_NAME" \
        --output none 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Not found${NC}"
        VALIDATION_FAILED=true
    fi
done
echo ""

if [ "$VALIDATION_FAILED" = true ]; then
    echo -e "${RED}ERROR: One or more image definitions not found in gallery${NC}"
    echo "Please ensure all images are created in the gallery before running this script."
    exit 1
fi

echo -e "${GREEN}✓ All image definitions validated${NC}"
echo ""

# Tracking arrays for results
declare -a SUCCESSFUL_IMAGES=()
declare -a FAILED_IMAGES=()

# Create logs directory with timestamp
LOG_DIR="$PROJECT_ROOT/logs/multi-image-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"

echo -e "${BLUE}Logs will be saved to: $LOG_DIR${NC}"
echo ""

# Workflow start time
WORKFLOW_START_TIME=$(date +%s)

# Process each image
CURRENT_IMAGE=0
for IMAGE_NAME in "${IMAGE_LIST[@]}"; do
    CURRENT_IMAGE=$((CURRENT_IMAGE + 1))
    
    echo ""
    echo -e "${MAGENTA}════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}Processing Image $CURRENT_IMAGE of $IMAGE_COUNT: $IMAGE_NAME${NC}"
    echo -e "${MAGENTA}════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Create log file for this image
    IMAGE_LOG="$LOG_DIR/${IMAGE_NAME}.log"
    
    # Construct the full image path for AZURE_SOURCE_IMAGE
    AZURE_SOURCE_IMAGE_OVERRIDE="/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$GALLERY_RG/providers/Microsoft.Compute/galleries/$AZURE_GALLERY_NAME/images/$IMAGE_NAME"
    
    echo -e "${BLUE}Image Configuration:${NC}"
    echo "  Definition: $IMAGE_NAME"
    echo "  Source Path: $AZURE_SOURCE_IMAGE_OVERRIDE"
    echo "  Log File: $IMAGE_LOG"
    echo ""
    
    # Create temporary .env with overridden values for this image
    # Backup original .env
    cp "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.backup"
    
    # Update .env with current image
    sed -i.tmp "s|^export AZURE_IMAGE_DEFINITION=.*|export AZURE_IMAGE_DEFINITION=\"$IMAGE_NAME\"|" "$PROJECT_ROOT/.env"
    sed -i.tmp "s|^export AZURE_SOURCE_IMAGE=.*|export AZURE_SOURCE_IMAGE=\"$AZURE_SOURCE_IMAGE_OVERRIDE\"|" "$PROJECT_ROOT/.env"
    rm -f "$PROJECT_ROOT/.env.tmp"
    
    # Start timestamp
    START_TIME=$(date +%s)
    echo "Started at: $(date)" | tee "$IMAGE_LOG"
    echo "" | tee -a "$IMAGE_LOG"
    
    # Run the workflow
    echo -e "${BLUE}Running automated workflow for $IMAGE_NAME...${NC}" | tee -a "$IMAGE_LOG"
    echo "" | tee -a "$IMAGE_LOG"
    
    # Run with proper environment inheritance and signal handling
    # Use exec redirection to avoid pipeline blocking issues with nested tee commands
    if bash "$SCRIPT_DIR/test-full-workflow.sh" >> "$IMAGE_LOG" 2>&1; then
        # Success
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        DURATION_MIN=$((DURATION / 60))
        DURATION_SEC=$((DURATION % 60))
        
        echo "" | tee -a "$IMAGE_LOG"
        echo -e "${GREEN}✓ Successfully processed $IMAGE_NAME${NC}" | tee -a "$IMAGE_LOG"
        echo "Duration: ${DURATION_MIN}m ${DURATION_SEC}s" | tee -a "$IMAGE_LOG"
        
        SUCCESSFUL_IMAGES+=("$IMAGE_NAME")
    else
        # Failure
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        DURATION_MIN=$((DURATION / 60))
        DURATION_SEC=$((DURATION % 60))
        
        echo "" | tee -a "$IMAGE_LOG"
        echo -e "${RED}✗ Failed to process $IMAGE_NAME${NC}" | tee -a "$IMAGE_LOG"
        echo "Duration: ${DURATION_MIN}m ${DURATION_SEC}s" | tee -a "$IMAGE_LOG"
        
        FAILED_IMAGES+=("$IMAGE_NAME")
        
        # Continue with next image (don't stop on failure)
        echo ""
        echo -e "${YELLOW}Continuing with remaining images...${NC}"
    fi
    
    # Restore original .env after each image (success or failure)
    mv "$PROJECT_ROOT/.env.backup" "$PROJECT_ROOT/.env"
    
    echo ""
done

# Calculate total workflow duration
WORKFLOW_END_TIME=$(date +%s)
TOTAL_DURATION=$((WORKFLOW_END_TIME - WORKFLOW_START_TIME))
TOTAL_DURATION_MIN=$((TOTAL_DURATION / 60))
TOTAL_DURATION_SEC=$((TOTAL_DURATION % 60))

# Final Summary Report
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Multi-Image Workflow Complete${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}Summary:${NC}"
echo "  Total Images: $IMAGE_COUNT"
echo "  Successful: ${#SUCCESSFUL_IMAGES[@]}"
echo "  Failed: ${#FAILED_IMAGES[@]}"
echo "  Total Duration: ${TOTAL_DURATION_MIN}m ${TOTAL_DURATION_SEC}s"
echo ""

if [ ${#SUCCESSFUL_IMAGES[@]} -gt 0 ]; then
    echo -e "${GREEN}Successful Images:${NC}"
    for img in "${SUCCESSFUL_IMAGES[@]}"; do
        echo "  ✓ $img"
    done
    echo ""
fi

if [ ${#FAILED_IMAGES[@]} -gt 0 ]; then
    echo -e "${RED}Failed Images:${NC}"
    for img in "${FAILED_IMAGES[@]}"; do
        echo "  ✗ $img"
    done
    echo ""
fi

echo -e "${BLUE}Logs saved to: $LOG_DIR${NC}"
echo ""

# Exit with appropriate code
if [ ${#FAILED_IMAGES[@]} -gt 0 ]; then
    echo -e "${YELLOW}Workflow completed with failures${NC}"
    exit 1
else
    echo -e "${GREEN}All images processed successfully! 🎉${NC}"
    exit 0
fi

# Made with Bob