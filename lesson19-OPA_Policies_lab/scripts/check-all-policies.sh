#!/bin/bash

set -e

echo "=================================================="
echo "  OPA Policy Validation for OpenTofu"
echo "=================================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Change to project root
cd "$(dirname "$0")/.."

# Step 1: Run policy tests
echo "📋 Step 1: Running policy unit tests..."
echo ""
cd policies
if opa test . --verbose; then
    echo -e "${GREEN}✅ All policy tests passed${NC}"
else
    echo -e "${RED}❌ Policy tests failed${NC}"
    exit 1
fi
echo ""

# Step 2: Generate OpenTofu plan
echo "📋 Step 2: Generating OpenTofu plan..."
echo ""
cd ../infrastructure
tofu plan -out=tfplan.binary > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Plan generated successfully${NC}"
else
    echo -e "${RED}❌ Failed to generate plan${NC}"
    exit 1
fi

# Convert to JSON
tofu show -json tfplan.binary > tfplan.json
echo -e "${GREEN}✅ Plan converted to JSON${NC}"
echo ""

# Step 3: Evaluate tagging policies
echo "=================================================="
echo "  Evaluating Tagging Policies"
echo "=================================================="
cd ../policies

TAGGING_RESULT=$(opa eval --data tagging.rego \
    --input ../infrastructure/tfplan.json \
    --format pretty \
    'data.terraform.tagging.deny')

if [ "$TAGGING_RESULT" != "[]" ]; then
    echo -e "${RED}❌ Tagging violations found:${NC}"
    echo "$TAGGING_RESULT" | jq -r '.[]' 
    TAGGING_FAILED=1
else
    echo -e "${GREEN}✅ No tagging violations${NC}"
    TAGGING_FAILED=0
fi
echo ""

# Step 4: Evaluate security policies
echo "=================================================="
echo "  Evaluating Security Policies"
echo "=================================================="

SECURITY_RESULT=$(opa eval --data security.rego \
    --input ../infrastructure/tfplan.json \
    --format pretty \
    'data.terraform.security.deny')

if [ "$SECURITY_RESULT" != "[]" ]; then
    echo -e "${RED}❌ Security violations found:${NC}"
    echo "$SECURITY_RESULT" | jq -r '.[]'
    SECURITY_FAILED=1
else
    echo -e "${GREEN}✅ No security violations${NC}"
    SECURITY_FAILED=0
fi
echo ""

# Step 5: Evaluate cost policies
echo "=================================================="
echo "  Evaluating Cost Policies"
echo "=================================================="

COST_RESULT=$(opa eval --data cost.rego \
    --input ../infrastructure/tfplan.json \
    --format pretty \
    'data.terraform.cost.deny')

if [ "$COST_RESULT" != "[]" ]; then
    echo -e "${YELLOW}⚠️  Cost violations found:${NC}"
    echo "$COST_RESULT" | jq -r '.[]'
    COST_FAILED=1
else
    echo -e "${GREEN}✅ No cost violations${NC}"
    COST_FAILED=0
fi
echo ""

# Step 6: Show warnings
echo "=================================================="
echo "  Policy Warnings (Non-blocking)"
echo "=================================================="

# Tagging warnings
TAGGING_WARNINGS=$(opa eval --data tagging.rego \
    --input ../infrastructure/tfplan.json \
    --format pretty \
    'data.terraform.tagging.warn')

# Security warnings
SECURITY_WARNINGS=$(opa eval --data security.rego \
    --input ../infrastructure/tfplan.json \
    --format pretty \
    'data.terraform.security.warn')

# Cost warnings
COST_WARNINGS=$(opa eval --data cost.rego \
    --input ../infrastructure/tfplan.json \
    --format pretty \
    'data.terraform.cost.warn')

ALL_WARNINGS=$(echo "$TAGGING_WARNINGS" "$SECURITY_WARNINGS" "$COST_WARNINGS" | jq -s 'add')

if [ "$ALL_WARNINGS" != "[]" ] && [ "$ALL_WARNINGS" != "null" ]; then
    echo -e "${YELLOW}⚠️  Warnings:${NC}"
    echo "$ALL_WARNINGS" | jq -r '.[]'
else
    echo -e "${GREEN}✅ No warnings${NC}"
fi
echo ""

# Final summary
echo "=================================================="
echo "  Final Summary"
echo "=================================================="

TOTAL_FAILED=$((TAGGING_FAILED + SECURITY_FAILED + COST_FAILED))

if [ $TOTAL_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL POLICIES PASSED${NC}"
    echo ""
    echo "You can proceed with: tofu apply"
    exit 0
else
    echo -e "${RED}❌ POLICY VIOLATIONS DETECTED${NC}"
    echo ""
    echo "Please fix the violations above before applying."
    echo "Failed policy categories:"
    [ $TAGGING_FAILED -eq 1 ] && echo "  - Tagging"
    [ $SECURITY_FAILED -eq 1 ] && echo "  - Security"
    [ $COST_FAILED -eq 1 ] && echo "  - Cost"
    exit 1
fi