#!/bin/bash
# Automated test script for Library Management API

BASE="http://localhost:5000"
PASS=0
FAIL=0

ok()  { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail(){ echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

check() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    if echo "$actual" | grep -q "$expected"; then
        ok "$label"
    else
        fail "$label — expected '$expected' in: $actual"
    fi
}

echo "================================================"
echo "  Library Management API – Automated Tests"
echo "================================================"
echo ""

# ── Health ────────────────────────────────────────
echo "[ Health ]"
R=$(curl -sf "$BASE/health")
check "GET /health returns ok" '"ok"' "$R"
echo ""

# ── Books ─────────────────────────────────────────
echo "[ Books ]"
R=$(curl -sf "$BASE/books")
check "GET /books returns list"       "title"      "$R"
check "GET /books has sample data"    "Clean Code" "$R"

R=$(curl -sf "$BASE/books/1")
check "GET /books/1 returns book"     "Pragmatic"  "$R"

R=$(curl -sf -X POST "$BASE/books" \
    -H "Content-Type: application/json" \
    -d '{"title":"Kubernetes in Action","author":"Marko Luksa","isbn":"978-1617293726"}')
check "POST /books creates book"      "Kubernetes"  "$R"
NEW_ID=$(echo "$R" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)

R=$(curl -sf -X PUT "$BASE/books/$NEW_ID" \
    -H "Content-Type: application/json" \
    -d '{"title":"Kubernetes in Action (2nd Ed)","author":"Marko Luksa","isbn":"978-1617293726"}')
check "PUT /books/$NEW_ID updates book" "2nd Ed" "$R"
echo ""

# ── Users ─────────────────────────────────────────
echo "[ Users ]"
R=$(curl -sf "$BASE/users")
check "GET /users returns list"        "Alice"      "$R"

R=$(curl -sf "$BASE/users/1")
check "GET /users/1 returns user"      "alice@"     "$R"

R=$(curl -sf -X POST "$BASE/users" \
    -H "Content-Type: application/json" \
    -d '{"name":"David Testowy","email":"david@testowy.pl"}')
check "POST /users registers user"     "David"      "$R"
echo ""

# ── Loans ─────────────────────────────────────────
echo "[ Loans ]"
R=$(curl -sf "$BASE/loans")
check "GET /loans returns list"        "book_title" "$R"

R=$(curl -sf -X POST "$BASE/loans" \
    -H "Content-Type: application/json" \
    -d '{"book_id":3,"user_id":1}')
check "POST /loans creates loan"       "loan_date"  "$R"
LOAN_ID=$(echo "$R" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)

R=$(curl -sf -X POST "$BASE/loans/$LOAN_ID/return")
check "POST /loans/$LOAN_ID/return"    "successfully" "$R"

R=$(curl -sf "$BASE/loans/overdue")
check "GET /loans/overdue returns data" "days_overdue" "$R"
echo ""

# ── Error handling ────────────────────────────────
echo "[ Error handling ]"
R=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/books/9999")
check "GET non-existent book → 404"   "404" "$R"

R=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/loans" \
    -H "Content-Type: application/json" \
    -d '{"book_id":2,"user_id":1}')
check "Loan unavailable book → 400"   "400" "$R"
echo ""

# ── Summary ───────────────────────────────────────
echo "================================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "================================================"
[ "$FAIL" -eq 0 ]
