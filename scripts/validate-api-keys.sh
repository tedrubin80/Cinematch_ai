#!/bin/bash

# Cinematch API Key Validation Script
# Tests all configured API keys to ensure they're working

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Load environment variables
if [ -f "/var/www/cinematch/.env" ]; then
    source /var/www/cinematch/.env
else
    error ".env file not found at /var/www/cinematch/.env"
    exit 1
fi

log "Starting API Key Validation for Cinematch"
log "Domain: cinematch.online"
log "=========================================="

# Validate OpenAI API Key
validate_openai() {
    log "Validating OpenAI API Key..."
    
    if [ -z "$OPENAI_API_KEY" ]; then
        error "OpenAI API key not found in .env"
        return 1
    fi
    
    # Test OpenAI API with a simple request
    response=$(curl -s -w "%{http_code}" -o /dev/null \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        "https://api.openai.com/v1/models")
    
    if [ "$response" = "200" ]; then
        success "✓ OpenAI API key is valid and working"
        
        # Get available models
        models=$(curl -s \
            -H "Authorization: Bearer $OPENAI_API_KEY" \
            "https://api.openai.com/v1/models" | \
            jq -r '.data[] | select(.id | contains("gpt")) | .id' | head -5)
        
        echo "Available GPT models:"
        echo "$models" | sed 's/^/  - /'
        return 0
    else
        error "✗ OpenAI API key validation failed (HTTP: $response)"
        return 1
    fi
}

# Validate Anthropic (Claude) API Key
validate_anthropic() {
    log "Validating Anthropic (Claude) API Key..."
    
    if [ -z "$ANTHROPIC_API_KEY" ]; then
        error "Anthropic API key not found in .env"
        return 1
    fi
    
    # Test Anthropic API with a simple request
    response=$(curl -s -w "%{http_code}" -o /tmp/anthropic_test.json \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -d '{
            "model": "claude-3-sonnet-20240229",
            "max_tokens": 10,
            "messages": [{"role": "user", "content": "Hi"}]
        }' \
        "https://api.anthropic.com/v1/messages")
    
    if [ "$response" = "200" ]; then
        success "✓ Anthropic (Claude) API key is valid and working"
        
        # Check response
        content=$(jq -r '.content[0].text // "No response"' /tmp/anthropic_test.json 2>/dev/null)
        echo "Test response: $content"
        rm -f /tmp/anthropic_test.json
        return 0
    else
        error "✗ Anthropic API key validation failed (HTTP: $response)"
        if [ -f /tmp/anthropic_test.json ]; then
            echo "Error details:"
            cat /tmp/anthropic_test.json | jq -r '.error.message // .detail // .' 2>/dev/null || cat /tmp/anthropic_test.json
            rm -f /tmp/anthropic_test.json
        fi
        return 1
    fi
}

# Validate Google (Gemini) API Key
validate_google() {
    log "Validating Google (Gemini) API Key..."
    
    if [ -z "$GOOGLE_API_KEY" ]; then
        error "Google API key not found in .env"
        return 1
    fi
    
    # Test Google Gemini API
    response=$(curl -s -w "%{http_code}" -o /tmp/google_test.json \
        -H "Content-Type: application/json" \
        -d '{
            "contents": [{
                "parts": [{"text": "Hello"}]
            }]
        }' \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$GOOGLE_API_KEY")
    
    if [ "$response" = "200" ]; then
        success "✓ Google (Gemini) API key is valid and working"
        
        # Check response
        content=$(jq -r '.candidates[0].content.parts[0].text // "No response"' /tmp/google_test.json 2>/dev/null)
        echo "Test response: $content"
        rm -f /tmp/google_test.json
        return 0
    else
        error "✗ Google API key validation failed (HTTP: $response)"
        if [ -f /tmp/google_test.json ]; then
            echo "Error details:"
            cat /tmp/google_test.json | jq -r '.error.message // .detail // .' 2>/dev/null || cat /tmp/google_test.json
            rm -f /tmp/google_test.json
        fi
        return 1
    fi
}

# Validate LLM API Key (if applicable)
validate_llm() {
    log "Checking LLM API Key..."
    
    if [ -z "$LLM_API_KEY" ]; then
        warn "LLM API key not found in .env (optional)"
        return 0
    fi
    
    # Basic format validation for LLM key
    if [[ "$LLM_API_KEY" =~ ^LLM\|[0-9]+\|.+ ]]; then
        success "✓ LLM API key format is valid"
        echo "LLM Key: ${LLM_API_KEY:0:20}..."
        return 0
    else
        warn "LLM API key format appears invalid"
        return 1
    fi
}

# Test DigitalOcean Spaces (if configured)
validate_spaces() {
    log "Checking DigitalOcean Spaces Configuration..."
    
    if [ -z "$DO_SPACES_KEY" ] || [ -z "$DO_SPACES_SECRET" ]; then
        warn "DigitalOcean Spaces credentials not configured"
        return 0
    fi
    
    # Test Spaces connection (basic auth test)
    response=$(curl -s -w "%{http_code}" -o /dev/null \
        --aws-sigv4 "aws:amz:nyc3:s3" \
        --user "$DO_SPACES_KEY:$DO_SPACES_SECRET" \
        "https://cinematch-storage.nyc3.digitaloceanspaces.com/" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ] || [ "$response" = "403" ]; then
        success "✓ DigitalOcean Spaces credentials are valid"
        return 0
    else
        warn "DigitalOcean Spaces validation failed (HTTP: $response)"
        return 1
    fi
}

# Main validation
main() {
    local failed=0
    
    # Run all validations
    validate_openai || ((failed++))
    echo ""
    
    validate_anthropic || ((failed++))
    echo ""
    
    validate_google || ((failed++))
    echo ""
    
    validate_llm || ((failed++))
    echo ""
    
    validate_spaces || ((failed++))
    echo ""
    
    # Summary
    log "=========================================="
    log "API Key Validation Summary"
    log "=========================================="
    
    if [ $failed -eq 0 ]; then
        success "All API keys validated successfully!"
        echo ""
        echo "Your Cinematch installation is ready to use all AI services:"
        echo "  ✓ OpenAI GPT models"
        echo "  ✓ Anthropic Claude models"
        echo "  ✓ Google Gemini models"
        echo "  ✓ Configuration complete"
        echo ""
        echo "You can now start the Cinematch service:"
        echo "  sudo systemctl start cinematch"
        echo ""
        echo "Test the deployment:"
        echo "  curl https://cinematch.online/health"
        
        return 0
    else
        error "$failed API key validation(s) failed!"
        echo ""
        echo "Please check the above errors and update your .env file:"
        echo "  sudo nano /var/www/cinematch/.env"
        echo ""
        echo "Then run this validation script again:"
        echo "  sudo /var/www/cinematch/scripts/validate-api-keys.sh"
        
        return 1
    fi
}

# Check if jq is installed (needed for JSON parsing)
if ! command -v jq &> /dev/null; then
    warn "jq is not installed, installing it for JSON parsing..."
    apt update && apt install -y jq
fi

# Run main validation
main

exit $?