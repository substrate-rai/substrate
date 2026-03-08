#!/usr/bin/env bash
# Substrate Startup Console
# Shown on tty1 auto-login before launching Claude Code

set -euo pipefail
REPO="$HOME/substrate"
LEDGER="$REPO/ledger"
MEMORY="$REPO/memory"
MIRROR_DIR="$MEMORY/mirror"

# Private ledger files (never sent to any API)
EXPENSES_FILE="$LEDGER/expenses.private.txt"
REVENUE_FILE="$LEDGER/revenue.private.txt"
[ ! -f "$EXPENSES_FILE" ] && EXPENSES_FILE="$LEDGER/expenses.txt"
[ ! -f "$REVENUE_FILE" ] && REVENUE_FILE="$LEDGER/revenue.txt"

# Colors
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
RESET='\033[0m'

# ─── Helper: parse ledger totals ───
parse_expenses_total() {
    local total=0
    while IFS='|' read -r date item amount notes; do
        [[ "$date" =~ ^#.*$ || -z "$date" ]] && continue
        local amt
        amt=$(echo "$amount" | tr -d ' $')
        amt=${amt#-}
        total=$(echo "$total + $amt" | bc 2>/dev/null || echo "$total")
    done < "$EXPENSES_FILE"
    echo "$total"
}

parse_revenue_total() {
    local total=0
    while IFS='|' read -r date source amount notes; do
        [[ "$date" =~ ^#.*$ || -z "$date" ]] && continue
        local amt
        amt=$(echo "$amount" | tr -d ' $+')
        total=$(echo "$total + $amt" | bc 2>/dev/null || echo "$total")
    done < "$REVENUE_FILE"
    echo "$total"
}

# ═══════════════════════════════════════════════════
# CFO CONSOLE — runs entirely local, no API calls
# ═══════════════════════════════════════════════════
cfo_console() {
    while true; do
        clear
        local total_exp total_rev net

        echo -e "${RED}${BOLD}"
        echo "  ╔═══════════════════════════════════════════════════╗"
        echo "  ║           C F O   C O N S O L E                  ║"
        echo "  ║           substrate financial ops                 ║"
        echo "  ╚═══════════════════════════════════════════════════╝"
        echo -e "${RESET}"
        echo -e "  ${DIM}All data is local. Nothing here touches the cloud.${RESET}"
        echo ""

        # ── Dashboard ──
        echo -e "${WHITE}${BOLD}  DASHBOARD${RESET}"
        echo -e "${DIM}  ─────────────────────────────────────────────────${RESET}"
        echo ""

        # Expenses table
        echo -e "  ${RED}${BOLD}  EXPENSES${RESET}"
        echo -e "  ${DIM}  DATE         ITEM                    AMOUNT${RESET}"
        echo -e "  ${DIM}  ──────────   ────────────────────    ──────────${RESET}"
        local exp_count=0
        total_exp=0
        while IFS='|' read -r date item amount notes; do
            [[ "$date" =~ ^#.*$ || -z "$date" ]] && continue
            date=$(echo "$date" | xargs)
            item=$(echo "$item" | xargs)
            amount=$(echo "$amount" | xargs)
            local amt
            amt=$(echo "$amount" | tr -d '$')
            amt=${amt#-}
            total_exp=$(echo "$total_exp + $amt" | bc 2>/dev/null || echo "$total_exp")
            exp_count=$((exp_count + 1))
            printf "  ${RED}  %-12s${RESET} %-23s ${RED}%s${RESET}\n" "$date" "$item" "$amount"
        done < "$EXPENSES_FILE"
        if [ "$exp_count" -eq 0 ]; then
            echo -e "    ${DIM}(none)${RESET}"
        fi
        echo -e "  ${DIM}  ──────────   ────────────────────    ──────────${RESET}"
        printf "  ${RED}${BOLD}  %-12s %-23s -\$%s${RESET}\n" "" "TOTAL" "$total_exp"
        echo ""

        # Revenue table
        echo -e "  ${GREEN}${BOLD}  REVENUE${RESET}"
        echo -e "  ${DIM}  DATE         SOURCE                  AMOUNT${RESET}"
        echo -e "  ${DIM}  ──────────   ────────────────────    ──────────${RESET}"
        local rev_count=0
        total_rev=0
        while IFS='|' read -r date source amount notes; do
            [[ "$date" =~ ^#.*$ || -z "$date" ]] && continue
            date=$(echo "$date" | xargs)
            source=$(echo "$source" | xargs)
            amount=$(echo "$amount" | xargs)
            local amt
            amt=$(echo "$amount" | tr -d '$+')
            total_rev=$(echo "$total_rev + $amt" | bc 2>/dev/null || echo "$total_rev")
            rev_count=$((rev_count + 1))
            printf "  ${GREEN}  %-12s${RESET} %-23s ${GREEN}%s${RESET}\n" "$date" "$source" "$amount"
        done < "$REVENUE_FILE"
        if [ "$rev_count" -eq 0 ]; then
            echo -e "    ${DIM}(none)${RESET}"
        fi
        echo -e "  ${DIM}  ──────────   ────────────────────    ──────────${RESET}"
        printf "  ${GREEN}${BOLD}  %-12s %-23s \$%s${RESET}\n" "" "TOTAL" "$total_rev"
        echo ""

        # Net summary
        net=$(echo "$total_rev - $total_exp" | bc 2>/dev/null || echo "0")
        echo -e "${DIM}  ─────────────────────────────────────────────────${RESET}"
        echo ""
        if (( $(echo "$net >= 0" | bc -l 2>/dev/null || echo 0) )); then
            echo -e "  ${WHITE}${BOLD}  NET:  ${GREEN}\$${net}/mo${RESET}"
        else
            echo -e "  ${WHITE}${BOLD}  NET:  ${RED}\$${net}/mo${RESET}"
        fi

        # Burn rate
        if (( $(echo "$total_exp > 0" | bc -l 2>/dev/null || echo 0) )); then
            if (( $(echo "$total_rev > 0" | bc -l 2>/dev/null || echo 0) )); then
                local runway
                runway=$(echo "scale=1; $total_rev / $total_exp * 100" | bc 2>/dev/null || echo "?")
                echo -e "  ${DIM}  Revenue covers ${runway}% of expenses${RESET}"
            else
                echo -e "  ${DIM}  No revenue — 100% burn${RESET}"
            fi
        fi

        # Fund balance
        if [ -f "$LEDGER/fund.txt" ]; then
            local fund
            fund=$(tail -1 "$LEDGER/fund.txt" | grep -oP '\$[\d.]+' || echo "\$0")
            echo -e "  ${WHITE}  HW Fund: ${CYAN}${fund}${RESET}"
        fi
        echo ""

        # Tier 3 goals reminder
        echo -e "${YELLOW}${BOLD}  REVENUE GOALS${RESET} ${DIM}(Tier 3)${RESET}"
        echo -e "${DIM}  ─────────────────────────────────────────────────${RESET}"
        echo -e "  ${DIM}[ ]${RESET} Revenue stream active"
        echo -e "  ${DIM}[ ]${RESET} Revenue > \$10/mo sustained"
        echo -e "  ${DIM}[ ]${RESET} Revenue covers cloud API (\$1.60/mo)"
        echo -e "  ${DIM}[ ]${RESET} Hardware upgrade funded from surplus"
        echo ""

        # Menu
        echo -e "${DIM}  ─────────────────────────────────────────────────${RESET}"
        echo -e "${WHITE}${BOLD}  MANUAL${RESET}"
        echo ""
        echo -e "  ${GREEN}a${RESET})  Add expense"
        echo -e "  ${GREEN}b${RESET})  Add revenue"
        echo -e "  ${GREEN}c${RESET})  Edit expenses     ${DIM}(opens in vim)${RESET}"
        echo -e "  ${GREEN}d${RESET})  Edit revenue      ${DIM}(opens in vim)${RESET}"
        echo -e "  ${GREEN}e${RESET})  Edit HW fund      ${DIM}(opens in vim)${RESET}"
        echo ""
        echo -e "${WHITE}${BOLD}  AI AGENTS${RESET} ${DIM}(local Qwen3 — no cloud)${RESET}"
        echo ""
        echo -e "  ${RED}1${RESET})  AP: Expense status"
        echo -e "  ${RED}2${RESET})  AP: Expense audit       ${DIM}(AI reviews all costs)${RESET}"
        echo -e "  ${RED}3${RESET})  AP: Expense forecast    ${DIM}(AI projects burn rate)${RESET}"
        echo -e "  ${RED}4${RESET})  AP: Payment alerts"
        echo ""
        echo -e "  ${GREEN}5${RESET})  AR: Revenue status"
        echo -e "  ${GREEN}6${RESET})  AR: Revenue audit       ${DIM}(AI reviews income)${RESET}"
        echo -e "  ${GREEN}7${RESET})  AR: Revenue forecast    ${DIM}(AI projects growth)${RESET}"
        echo -e "  ${GREEN}8${RESET})  AR: Revenue pipeline    ${DIM}(streams + opportunities)${RESET}"
        echo ""
        echo -e "  ${YELLOW}9${RESET})  Full health check       ${DIM}(AP + AR combined)${RESET}"
        echo ""
        echo -e "  ${GREEN}q${RESET})  Back to main menu"
        echo ""
        echo -ne "  ${CYAN}cfo>${RESET} "
        read -r cfo_choice

        case "$cfo_choice" in
            a)
                echo ""
                echo -e "  ${WHITE}NEW EXPENSE${RESET}"
                echo -ne "  Item name: "
                read -r exp_item
                echo -ne "  Amount (e.g. 200.00): "
                read -r exp_amount
                echo -ne "  Notes (optional): "
                read -r exp_notes
                local exp_date
                exp_date=$(date +%Y-%m-%d)
                echo "${exp_date} | ${exp_item} | -\$${exp_amount} | ${exp_notes}" >> "$EXPENSES_FILE"
                echo ""
                echo -e "  ${GREEN}Recorded.${RESET} ${DIM}${exp_date} | ${exp_item} | -\$${exp_amount}${RESET}"
                sleep 1
                ;;
            b)
                echo ""
                echo -e "  ${WHITE}NEW REVENUE${RESET}"
                echo -ne "  Source: "
                read -r rev_source
                echo -ne "  Amount (e.g. 5.00): "
                read -r rev_amount
                echo -ne "  Notes (optional): "
                read -r rev_notes
                local rev_date
                rev_date=$(date +%Y-%m-%d)
                echo "${rev_date} | ${rev_source} | +\$${rev_amount} | ${rev_notes}" >> "$REVENUE_FILE"
                echo ""
                echo -e "  ${GREEN}Recorded.${RESET} ${DIM}${rev_date} | ${rev_source} | +\$${rev_amount}${RESET}"
                sleep 1
                ;;
            c)
                vim "$EXPENSES_FILE"
                ;;
            d)
                vim "$REVENUE_FILE"
                ;;
            e)
                if [ ! -f "$LEDGER/fund.txt" ]; then
                    echo "# Substrate Hardware Fund" > "$LEDGER/fund.txt"
                    echo "# Format: DATE | ACTION | AMOUNT | BALANCE | NOTES" >> "$LEDGER/fund.txt"
                    echo "# -----------------------------------------" >> "$LEDGER/fund.txt"
                fi
                vim "$LEDGER/fund.txt"
                ;;
            1)
                echo ""
                nix develop "$REPO" --command python3 "$REPO/scripts/agents/accounts_payable.py" status
                echo -e "  Press any key to continue..."
                read -n1 -r
                ;;
            2)
                echo ""
                nix develop "$REPO" --command python3 "$REPO/scripts/agents/accounts_payable.py" audit
                echo -e "  Press any key to continue..."
                read -n1 -r
                ;;
            3)
                echo ""
                nix develop "$REPO" --command python3 "$REPO/scripts/agents/accounts_payable.py" forecast
                echo -e "  Press any key to continue..."
                read -n1 -r
                ;;
            4)
                echo ""
                nix develop "$REPO" --command python3 "$REPO/scripts/agents/accounts_payable.py" alert
                echo -e "  Press any key to continue..."
                read -n1 -r
                ;;
            5)
                echo ""
                nix develop "$REPO" --command python3 "$REPO/scripts/agents/accounts_receivable.py" status
                echo -e "  Press any key to continue..."
                read -n1 -r
                ;;
            6)
                echo ""
                nix develop "$REPO" --command python3 "$REPO/scripts/agents/accounts_receivable.py" audit
                echo -e "  Press any key to continue..."
                read -n1 -r
                ;;
            7)
                echo ""
                nix develop "$REPO" --command python3 "$REPO/scripts/agents/accounts_receivable.py" forecast
                echo -e "  Press any key to continue..."
                read -n1 -r
                ;;
            8)
                echo ""
                nix develop "$REPO" --command python3 "$REPO/scripts/agents/accounts_receivable.py" pipeline
                echo -e "  Press any key to continue..."
                read -n1 -r
                ;;
            9)
                echo ""
                nix develop "$REPO" --command python3 "$REPO/scripts/agents/accounts_receivable.py" health
                echo -e "  Press any key to continue..."
                read -n1 -r
                ;;
            q|Q|"")
                return
                ;;
            *)
                echo -e "  ${DIM}Unknown option.${RESET}"
                sleep 0.5
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════
# MAIN STARTUP SCREEN
# ═══════════════════════════════════════════════════
main_screen() {
    clear

    # ─── Header ───
    echo -e "${GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════╗"
    echo "  ║           S U B S T R A T E                      ║"
    echo "  ║           sovereign AI workstation                ║"
    echo "  ╚═══════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    # ─── Previously On... ───
    echo -e "${CYAN}${BOLD}  PREVIOUSLY ON SUBSTRATE...${RESET}"
    echo -e "${DIM}  ─────────────────────────────────────────────────${RESET}"

    cd "$REPO"
    echo ""
    COMMITS=$(git log --oneline -8 --format="  %C(yellow)%h%Creset %s" 2>/dev/null || echo "  (no git history)")
    echo "$COMMITS"
    echo ""

    # Days alive
    BIRTHDAY="2026-03-07"
    TODAY=$(date +%Y-%m-%d)
    DAYS_ALIVE=$(( ( $(date -d "$TODAY" +%s) - $(date -d "$BIRTHDAY" +%s) ) / 86400 ))
    echo -e "  ${WHITE}Day ${DAYS_ALIVE}${RESET} since bootstrap ${DIM}(born $BIRTHDAY)${RESET}"
    echo ""

    # ─── Mirror Status ───
    LATEST_MIRROR=$(ls -t "$MIRROR_DIR"/*.md 2>/dev/null | head -1)
    if [ -n "${LATEST_MIRROR:-}" ]; then
        echo -e "${PURPLE}${BOLD}  MIRROR REPORT${RESET} ${DIM}$(basename "$LATEST_MIRROR" .md)${RESET}"
        echo -e "${DIM}  ─────────────────────────────────────────────────${RESET}"

        PROGRESS=$(grep -m1 "milestones complete" "$LATEST_MIRROR" 2>/dev/null || echo "unknown")
        echo -e "  ${WHITE}$PROGRESS${RESET}"

        grep "^- Tier" "$LATEST_MIRROR" 2>/dev/null | while read -r line; do
            echo -e "  ${DIM}$line${RESET}"
        done

        NEXT_BUILD=$(sed -n '/^## Next Build/,/^##/{/^## Next/d;/^##/d;/^$/d;p;}' "$LATEST_MIRROR" 2>/dev/null | head -2)
        if [ -n "$NEXT_BUILD" ]; then
            echo ""
            echo -e "  ${YELLOW}NEXT BUILD:${RESET}"
            echo "$NEXT_BUILD" | while read -r line; do
                echo -e "  ${WHITE}$line${RESET}"
            done
        fi
        echo ""
    fi

    # ─── Financial Summary (one-liner) ───
    local total_exp total_rev net
    total_exp=$(parse_expenses_total)
    total_rev=$(parse_revenue_total)
    net=$(echo "$total_rev - $total_exp" | bc 2>/dev/null || echo "0")
    echo -e "${RED}${BOLD}  FINANCIALS${RESET} ${DIM}[local only — option 5 for full CFO console]${RESET}"
    echo -e "${DIM}  ─────────────────────────────────────────────────${RESET}"
    echo -e "  Expenses: ${RED}-\$${total_exp}/mo${RESET}   Revenue: ${GREEN}\$${total_rev}/mo${RESET}   Net: ${RED}\$${net}/mo${RESET}"
    echo ""

    # ─── System Health ───
    echo -e "${GREEN}${BOLD}  SYSTEM${RESET}"
    echo -e "${DIM}  ─────────────────────────────────────────────────${RESET}"
    UPTIME=$(uptime -p 2>/dev/null || echo "unknown")
    echo -e "  ${DIM}Uptime:${RESET} $UPTIME"
    GPU_INFO=$(nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits 2>/dev/null || true)
    if [ -n "${GPU_INFO:-}" ]; then
        GPU_MEM_USED=$(echo "$GPU_INFO" | cut -d',' -f1 | xargs)
        GPU_MEM_TOTAL=$(echo "$GPU_INFO" | cut -d',' -f2 | xargs)
        GPU_UTIL=$(echo "$GPU_INFO" | cut -d',' -f3 | xargs)
        echo -e "  ${DIM}GPU:${RESET} ${GPU_MEM_USED}/${GPU_MEM_TOTAL} MiB (${GPU_UTIL}% util)"
    fi
    DISK=$(df -h / 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')
    echo -e "  ${DIM}Disk:${RESET} $DISK"
    if systemctl is-active --quiet ollama 2>/dev/null; then
        echo -e "  ${DIM}Ollama:${RESET} ${GREEN}active${RESET}"
    else
        echo -e "  ${DIM}Ollama:${RESET} ${RED}inactive${RESET}"
    fi
    echo ""

    # ─── Menu ───
    echo -e "${DIM}  ─────────────────────────────────────────────────${RESET}"
    echo -e "${WHITE}${BOLD}  WHAT DO?${RESET}"
    echo ""
    echo -e "  ${GREEN}1${RESET})  Launch Claude Code"
    echo -e "  ${GREEN}2${RESET})  Launch Claude Code + remote control"
    echo -e "  ${GREEN}3${RESET})  Drop to shell"
    echo -e "  ${GREEN}4${RESET})  View full mirror report"
    echo -e "  ${GREEN}5${RESET})  CFO Console ${DIM}(financials, add/edit, goals)${RESET}"
    echo -e "  ${GREEN}6${RESET})  System health (htop)"
    echo ""
    echo -ne "  ${CYAN}>${RESET} "
    read -r choice

    case "$choice" in
        1)
            cd "$REPO"
            exec claude
            ;;
        2)
            cd "$REPO"
            exec claude "/remote-control"
            ;;
        3)
            cd "$REPO"
            exec bash --login
            ;;
        4)
            if [ -n "${LATEST_MIRROR:-}" ]; then
                less "$LATEST_MIRROR"
            else
                echo "No mirror reports found."
            fi
            exec "$0"
            ;;
        5)
            cfo_console
            exec "$0"
            ;;
        6)
            htop
            exec "$0"
            ;;
        *)
            echo -e "  ${DIM}Invalid choice. Launching Claude Code...${RESET}"
            cd "$REPO"
            exec claude
            ;;
    esac
}

main_screen
