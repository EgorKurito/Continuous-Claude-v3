#!/bin/bash

# Continuous Claude - Quick Fix Script
# Automatically fixes common installation issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔧 CONTINUOUS CLAUDE - QUICK FIX${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}This script will automatically fix common installation issues.${NC}"
echo ""

# Get project directory
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo -e "Project directory: ${BLUE}$PROJECT_DIR${NC}"
echo ""

# Ask for confirmation
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""

# Step 1: Create .env file
echo -e "${BLUE}[1/6]${NC} Checking .env file..."
if [ ! -f "$PROJECT_DIR/opc/.env" ]; then
    echo -e "${YELLOW}  → Creating .env file...${NC}"

    cat > "$PROJECT_DIR/opc/.env" << EOF
# Database connection
DATABASE_URL=postgresql://claude:claude_dev@localhost:5432/continuous_claude

# Optional API keys (leave empty if not using)
BRAINTRUST_API_KEY=
PERPLEXITY_API_KEY=
NIA_API_KEY=

# Project paths
CLAUDE_PROJECT_DIR=$PROJECT_DIR
EOF

    echo -e "${GREEN}  ✅ Created .env file${NC}"
else
    echo -e "${GREEN}  ✅ .env file exists${NC}"

    # Check if DATABASE_URL is present
    if ! grep -q "DATABASE_URL" "$PROJECT_DIR/opc/.env"; then
        echo -e "${YELLOW}  → Adding DATABASE_URL...${NC}"
        echo "DATABASE_URL=postgresql://claude:claude_dev@localhost:5432/continuous_claude" >> "$PROJECT_DIR/opc/.env"
    fi

    # Check if CLAUDE_PROJECT_DIR is present
    if ! grep -q "CLAUDE_PROJECT_DIR" "$PROJECT_DIR/opc/.env"; then
        echo -e "${YELLOW}  → Adding CLAUDE_PROJECT_DIR...${NC}"
        echo "CLAUDE_PROJECT_DIR=$PROJECT_DIR" >> "$PROJECT_DIR/opc/.env"
    fi
fi
echo ""

# Step 2: Install Python dependencies
echo -e "${BLUE}[2/6]${NC} Installing Python dependencies..."
cd "$PROJECT_DIR/opc"

if ! uv pip list | grep -q "sentence-transformers"; then
    echo -e "${YELLOW}  → Installing embeddings dependencies...${NC}"
    uv sync --extra embeddings --extra postgres
    echo -e "${GREEN}  ✅ Dependencies installed${NC}"
else
    echo -e "${GREEN}  ✅ Dependencies already installed${NC}"
fi
echo ""

# Step 3: Start Docker container
echo -e "${BLUE}[3/6]${NC} Checking Docker container..."
if ! docker ps --filter name=continuous-claude-postgres --filter status=running | grep -q postgres; then
    echo -e "${YELLOW}  → Starting PostgreSQL container...${NC}"
    docker compose up -d
    echo -e "${YELLOW}  → Waiting for container to be healthy (30s)...${NC}"
    sleep 30
    echo -e "${GREEN}  ✅ Container started${NC}"
else
    echo -e "${GREEN}  ✅ Container already running${NC}"
fi
echo ""

# Step 4: Check database tables
echo -e "${BLUE}[4/6]${NC} Checking database tables..."
TABLES_COUNT=$(docker exec continuous-claude-postgres psql -U claude -d continuous_claude -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" 2>/dev/null | tr -d ' ')

if [ "$TABLES_COUNT" -lt 4 ]; then
    echo -e "${YELLOW}  → Creating database tables...${NC}"
    docker exec -i continuous-claude-postgres psql -U claude -d continuous_claude < "$PROJECT_DIR/docker/init-schema.sql"
    echo -e "${GREEN}  ✅ Tables created${NC}"
else
    echo -e "${GREEN}  ✅ Tables exist (count: $TABLES_COUNT)${NC}"
fi
echo ""

# Step 5: Verify hooks
echo -e "${BLUE}[5/6]${NC} Checking hooks..."
HOOKS_COUNT=$(ls -1 ~/.claude/hooks/dist/*.mjs 2>/dev/null | wc -l | tr -d ' ')

if [ "$HOOKS_COUNT" -lt 60 ]; then
    echo -e "${YELLOW}  → Rebuilding hooks...${NC}"
    if [ -f ~/.claude/hooks/build.sh ]; then
        cd ~/.claude/hooks
        ./build.sh
        echo -e "${GREEN}  ✅ Hooks rebuilt${NC}"
    else
        echo -e "${RED}  ⚠️  build.sh not found, skipping...${NC}"
    fi
else
    echo -e "${GREEN}  ✅ Hooks compiled (count: $HOOKS_COUNT)${NC}"
fi
echo ""

# Step 6: Test functionality
echo -e "${BLUE}[6/6]${NC} Testing memory system..."
cd "$PROJECT_DIR/opc"

TEST_OUTPUT=$(PYTHONPATH=. uv run python scripts/core/store_learning.py \
    --session-id "quick-fix-test" \
    --type WORKING_SOLUTION \
    --content "Quick fix completed successfully" \
    --context "Automated fix test" \
    --tags "fix,automated" \
    --confidence high 2>&1)

if echo "$TEST_OUTPUT" | grep -q "Backend: postgres"; then
    echo -e "${GREEN}  ✅ Store learning: Working (Backend: postgres)${NC}"
else
    echo -e "${RED}  ❌ Store learning: Failed${NC}"
    echo -e "${YELLOW}  Output: $TEST_OUTPUT${NC}"
fi

RECALL_OUTPUT=$(PYTHONPATH=. uv run python scripts/core/recall_learnings.py --query "quick-fix" --k 1 2>&1)

if echo "$RECALL_OUTPUT" | grep -q "Found.*matching learnings"; then
    echo -e "${GREEN}  ✅ Recall learning: Working${NC}"
else
    echo -e "${RED}  ❌ Recall learning: Failed${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Quick fix completed!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Run verification:${NC}"
echo "  bash quick-check.sh"
echo ""
echo -e "${BLUE}Start using:${NC}"
echo "  cd $PROJECT_DIR"
echo "  claude"
echo ""
