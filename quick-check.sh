#!/bin/bash

# Continuous Claude - Quick Installation Check
# Run this script to verify your installation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔍 CONTINUOUS CLAUDE - INSTALLATION CHECK${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Function to check and print result
check() {
    local name="$1"
    local command="$2"
    local expected="$3"

    echo -n "Checking $name... "

    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        if [ -n "$expected" ]; then
            echo -e "  ${YELLOW}Expected: $expected${NC}"
        fi
        ((FAILED++))
        return 1
    fi
}

# 1. Prerequisites
echo -e "${BLUE}═══ 1. Prerequisites ═══${NC}"
check "Python 3.11+" "python3 --version | grep -E 'Python 3\.(1[1-9]|[2-9][0-9])'" "Python 3.11 or higher"
check "uv package manager" "uv --version"
check "Docker" "docker --version"
check "Docker running" "docker ps"
check "Claude Code CLI" "which claude" "claude in PATH"
echo ""

# 2. Project structure
echo -e "${BLUE}═══ 2. Project Structure ═══${NC}"
check "opc/ directory" "test -d opc"
check ".claude/ directory" "test -d .claude"
check "docker/ directory" "test -d docker"
check "docs/ directory" "test -d docs"
echo ""

# 3. Docker container
echo -e "${BLUE}═══ 3. Docker Container ═══${NC}"
check "PostgreSQL container" "docker ps --filter name=continuous-claude-postgres --filter status=running | grep -q postgres"
check "Container healthy" "docker ps --filter name=continuous-claude-postgres | grep -q healthy"
echo ""

# 4. Database
echo -e "${BLUE}═══ 4. Database ═══${NC}"
check "Database connection" "docker exec continuous-claude-postgres psql -U claude -d continuous_claude -c 'SELECT 1' | grep -q '1 row'"
check "Table: sessions" "docker exec continuous-claude-postgres psql -U claude -d continuous_claude -c '\dt' | grep -q sessions"
check "Table: archival_memory" "docker exec continuous-claude-postgres psql -U claude -d continuous_claude -c '\dt' | grep -q archival_memory"
check "Table: file_claims" "docker exec continuous-claude-postgres psql -U claude -d continuous_claude -c '\dt' | grep -q file_claims"
check "Table: handoffs" "docker exec continuous-claude-postgres psql -U claude -d continuous_claude -c '\dt' | grep -q handoffs"
echo ""

# 5. Configuration
echo -e "${BLUE}═══ 5. Configuration ═══${NC}"
check ".env file" "test -f opc/.env"
check "DATABASE_URL in .env" "grep -q 'DATABASE_URL.*postgresql' opc/.env"
check "~/.claude/settings.json" "test -f ~/.claude/settings.json"
check "Agents installed" "test $(ls -1 ~/.claude/agents/ 2>/dev/null | wc -l) -gt 40"
check "Skills installed" "test $(ls -1 ~/.claude/skills/ 2>/dev/null | wc -l) -gt 100"
check "Hooks compiled" "test $(ls -1 ~/.claude/hooks/dist/*.mjs 2>/dev/null | wc -l) -gt 60"
echo ""

# 6. Python dependencies
echo -e "${BLUE}═══ 6. Python Dependencies ═══${NC}"
cd opc
check "python-dotenv" "uv pip list | grep -q python-dotenv"
check "sentence-transformers" "uv pip list | grep -q sentence-transformers"
check "torch" "uv pip list | grep -q torch"
check "pgvector" "uv pip list | grep -q pgvector"
check "asyncpg" "uv pip list | grep -q asyncpg"
cd ..
echo ""

# 7. TLDR
echo -e "${BLUE}═══ 7. Tools ═══${NC}"
check "TLDR installed" "which tldr"
if which tldr &>/dev/null; then
    TLDR_VERSION=$(tldr --version 2>/dev/null | head -1)
    echo -e "  ${GREEN}Version: $TLDR_VERSION${NC}"
fi
echo ""

# 8. Functional test
echo -e "${BLUE}═══ 8. Functional Test ═══${NC}"
echo -n "Testing store_learning.py... "

cd opc
TEST_OUTPUT=$(PYTHONPATH=. uv run python scripts/core/store_learning.py \
    --session-id "quick-check-test" \
    --type WORKING_SOLUTION \
    --content "Quick check verification" \
    --context "Automated test" \
    --confidence high 2>&1)

if echo "$TEST_OUTPUT" | grep -q "Backend: postgres"; then
    echo -e "${GREEN}✅ PASS${NC} (Backend: postgres)"
    ((PASSED++))
else
    echo -e "${RED}❌ FAIL${NC}"
    echo -e "${YELLOW}Output: $TEST_OUTPUT${NC}"
    ((FAILED++))
fi

echo -n "Testing recall_learnings.py... "
RECALL_OUTPUT=$(PYTHONPATH=. uv run python scripts/core/recall_learnings.py --query "quick-check" --k 1 2>&1)

if echo "$RECALL_OUTPUT" | grep -q "Found.*matching learnings"; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ FAIL${NC}"
    echo -e "${YELLOW}Output: $RECALL_OUTPUT${NC}"
    ((FAILED++))
fi
cd ..
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 SUMMARY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All checks passed! Continuous Claude is ready to use.${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. cd $(pwd)"
    echo "  2. claude"
    echo "  3. Try: /help or 'What can you do?'"
    exit 0
else
    echo -e "${RED}⚠️  Some checks failed. Please review the output above.${NC}"
    echo ""
    echo -e "${YELLOW}Common fixes:${NC}"
    echo "  • Docker not running: Start Docker Desktop"
    echo "  • .env missing: See INSTALLATION_CHECKLIST.md Step 5"
    echo "  • Dependencies missing: cd opc && uv sync --extra embeddings --extra postgres"
    echo "  • Components missing: cd opc && uv run python -m scripts.setup.wizard"
    echo ""
    echo -e "For detailed troubleshooting, see: ${BLUE}INSTALLATION_CHECKLIST.md${NC}"
    exit 1
fi
