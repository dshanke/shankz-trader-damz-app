# =============================================================================
# Shankz Trader - Client App Makefile
# =============================================================================
# This Makefile uses the installed shankz-trader-bot package for all operations.
# No Python code or shell scripts are included in the client app.
# =============================================================================

.PHONY: help install launch status stop stop-all \
        backtest backtest-all fetch fetch-futures \
        analyze-state analyze-state-paper analyze-state-backtest analyze-report \
        logs clean

# ──────────────────────────────────────────────
# Variables
# ──────────────────────────────────────────────
TICKER       ?= ES
CONFIG       ?= default
PORT         ?= 4002
LIB_VERSION  ?= 0.1.0
BOT_VERSION  ?= 0.1.0
USE_LIB_SOURCE ?= true

BOT := .venv/bin/shankz-trader-bot
# Get absolute path in Unix-style (works in Git Bash/WSL too)
ABSPATH := $(shell pwd)/$(BOT)

# Only override IB port when user explicitly passes PORT= on command line
ifeq ($(origin PORT),command line)
    PORT_FLAG := --ib-port $(PORT)
else
    PORT_FLAG :=
endif

DIST_REPO := dshanke/shankz-trader-dist
DIST_API  := https://api.github.com/repos/$(DIST_REPO)/releases

# OS detection for wheel filenames
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_S),Darwin)
    LIB_WHEEL := shankz_trader_lib-$(LIB_VERSION)-cp312-cp312-macosx_10_13_universal2.whl
    BOT_WHEEL := shankz_trader_bot-$(BOT_VERSION)-cp312-cp312-macosx_10_13_universal2.whl
else ifeq ($(UNAME_S),Linux)
    LIB_WHEEL := shankz_trader_lib-$(LIB_VERSION)-cp312-cp312-linux_x86_64.whl
    BOT_WHEEL := shankz_trader_bot-$(BOT_VERSION)-cp312-cp312-linux_x86_64.whl
else
    # Windows (MSYS/Git Bash)
    LIB_WHEEL := shankz_trader_lib-$(LIB_VERSION)-cp312-cp312-win_amd64.whl
    BOT_WHEEL := shankz_trader_bot-$(BOT_VERSION)-cp312-cp312-win_amd64.whl
endif

WHEEL_DIR := .wheels

# ──────────────────────────────────────────────
# Help
# ──────────────────────────────────────────────
help:
	@echo "Shankz Trader - Client App"
	@echo ""
	@echo "Setup:"
	@echo "  make install                              Install dependencies"
	@echo ""
	@echo "Live Trading:"
	@echo "  make launch TICKER=ES [PORT=...]          Launch trading (uses config port by default)"
	@echo "  make status                               Show all ticker statuses"
	@echo "  make stop TICKER=ES                       Stop specific ticker"
	@echo "  make stop-all                             Stop all tickers"
	@echo "  make logs TICKER=ES                       Tail live trading log"
	@echo ""
	@echo "Backtesting:"
	@echo "  make backtest TICKER=ES [CONFIG=default]   Run backtest"
	@echo "  make backtest-all [CONFIG=default]        Run backtest for all tickers"
	@echo ""
	@echo "Data Fetching:"
	@echo ""
	@echo "  Stocks (use START_DATE + DAYS):"
	@echo "    START_DATE is the anchor date (YYYY-MM-DD)"
	@echo "    DAYS can be positive (forward) or negative (backward)"
	@echo ""
	@echo "    Examples:"
	@echo "      make fetch TICKER=TQQQ START_DATE=2024-01-01 DAYS=90     # Jan 1 → Mar 31 (forward)"
	@echo "      make fetch TICKER=TQQQ START_DATE=2024-12-31 DAYS=-90    # Oct 2 → Dec 31 (backward)"
	@echo "      make fetch TICKER=SPY START_DATE=2024-01-01 DAYS=365    # Full year 2024"
	@echo ""
	@echo "  Futures (date range auto-determined from contract expiry):"
	@echo "    make fetch-futures TICKER=ES MONTH=202603 DAYS=90"
	@echo ""
	@echo "Analysis:"
	@echo "  make analyze-state TICKER=ES              Analyze live state.json (creates log file)"
	@echo "  make analyze-state-paper TICKER=ES        Analyze paper_state.json (creates log file)"
	@echo "  make analyze-state-backtest TICKER=ES     Analyze backtest_state.json (creates log file)"
	@echo "  make analyze-report TICKER=ES             Analyze latest backtest report"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean                                 Remove caches and temp files"
	@echo ""
	@echo "Port Override (overrides config yaml, used by launch/fetch):"
	@echo "  PORT=4001  IB Gateway Live     PORT=4002  IB Gateway Paper"
	@echo "  PORT=7496  TWS Live            PORT=7497  TWS Paper"
	@echo "  (if not set, launch uses the port from the ticker's config.yaml)"
	@echo ""
	@echo "Install Modes:"
	@echo "  USE_LIB_SOURCE=false  Install from pre-built wheels (default)"
	@echo "  USE_LIB_SOURCE=true   Install from local source (dev mode)"
	@echo ""
	@echo "Analysis Logs:"
	@echo "  State analysis creates logs in current directory:"
	@echo "    {mode}-{first_date}-{last_date}-state-analysis.log"
	@echo "  Example: backtest-20241221-20250130-state-analysis.log"

# ──────────────────────────────────────────────
# Install
# ──────────────────────────────────────────────
install:
ifeq ($(USE_LIB_SOURCE),true)
	@echo "Installing from local source (dev mode)..."
	@uv sync
	@echo "Done — installed from local source."
else
	@if [ -z "$(GITHUB_TOKEN)" ]; then \
		echo "Error: GITHUB_TOKEN is required for wheel install."; \
		echo ""; \
		echo "  export GITHUB_TOKEN=ghp_xxx"; \
		echo "  make install"; \
		echo ""; \
		echo "Or use local source mode:"; \
		echo "  USE_LIB_SOURCE=true make install"; \
		exit 1; \
	fi
	@echo "Installing from pre-built wheels..."
	@echo "  Lib: $(LIB_WHEEL) (tag: v$(LIB_VERSION))"
	@echo "  Bot: $(BOT_WHEEL) (tag: bot-v$(BOT_VERSION))"
	@mkdir -p $(WHEEL_DIR)
	@echo "Downloading lib wheel..."
	@ASSET_URL=$$(curl -sL \
		-H "Authorization: token $(GITHUB_TOKEN)" \
		"$(DIST_API)/tags/v$(LIB_VERSION)" \
		| python3 -c "import json,sys; r=json.load(sys.stdin); print([a['url'] for a in r['assets'] if a['name']=='$(LIB_WHEEL)'][0])") && \
	curl -sL \
		-H "Authorization: token $(GITHUB_TOKEN)" \
		-H "Accept: application/octet-stream" \
		"$$ASSET_URL" \
		-o "$(WHEEL_DIR)/$(LIB_WHEEL)"
	@echo "Downloading bot wheel..."
	@ASSET_URL=$$(curl -sL \
		-H "Authorization: token $(GITHUB_TOKEN)" \
		"$(DIST_API)/tags/bot-v$(BOT_VERSION)" \
		| python3 -c "import json,sys; r=json.load(sys.stdin); print([a['url'] for a in r['assets'] if a['name']=='$(BOT_WHEEL)'][0])") && \
	curl -sL \
		-H "Authorization: token $(GITHUB_TOKEN)" \
		-H "Accept: application/octet-stream" \
		"$$ASSET_URL" \
		-o "$(WHEEL_DIR)/$(BOT_WHEEL)"
	@uv venv
	@uv pip install "$(WHEEL_DIR)/$(LIB_WHEEL)"
	@uv pip install "$(WHEEL_DIR)/$(BOT_WHEEL)"
	@rm -rf $(WHEEL_DIR)
	@echo "Done — installed from wheels."
endif

# ──────────────────────────────────────────────
# Live Trading
# ──────────────────────────────────────────────
launch:
	@LIVE_DIR="tickers/$(TICKER)/live"; \
	CONFIG_FILE="$$LIVE_DIR/config.yaml"; \
	LOG_FILE="$$LIVE_DIR/trading.log"; \
	if [ ! -d "$$LIVE_DIR" ]; then \
		echo "Error: Ticker directory not found: $$LIVE_DIR"; \
		echo ""; \
		echo "Available tickers:"; \
		ls -1 tickers/ 2>/dev/null || echo "  (none)"; \
		exit 1; \
	fi; \
	if [ ! -f "$$CONFIG_FILE" ]; then \
		echo "Error: Config not found: $$CONFIG_FILE"; \
		exit 1; \
	fi; \
	echo "=========================================="; \
	echo "Launching $(TICKER)"; \
	echo "=========================================="; \
	echo "Config: $$CONFIG_FILE"; \
	echo "Log:    $$LOG_FILE"; \
	if [ -n "$(PORT_FLAG)" ]; then \
		echo "IB Port: $(PORT) (overriding config)"; \
	else \
		echo "IB Port: (from config)"; \
	fi; \
	echo "=========================================="; \
	echo ""; \
	echo "Running in foreground (Ctrl+C to stop)"; \
	echo ""; \
	cd "$$LIVE_DIR" && $(ABSPATH) run --config config.yaml $(PORT_FLAG) 2>&1 | tee -a trading.log

status:
	@$(BOT) status --tickers-dir tickers

stop:
	@$(BOT) stop --ticker $(TICKER) --tickers-dir tickers

stop-all:
	@$(BOT) stop --all --tickers-dir tickers

# ──────────────────────────────────────────────
# Backtesting
# ──────────────────────────────────────────────
backtest:
	@BACKTEST_DIR="tickers/$(TICKER)/backtest"; \
	CONFIG_FILE="$$BACKTEST_DIR/config/$(CONFIG).yaml"; \
	LOG_FILE="$$BACKTEST_DIR/reports/backtest_$(CONFIG).log"; \
	if [ ! -d "$$BACKTEST_DIR" ]; then \
		echo "Error: $(TICKER)/backtest not found"; \
		echo "Available tickers:"; \
		ls -1 tickers/ 2>/dev/null || echo "  (none)"; \
		exit 1; \
	fi; \
	if [ ! -f "$$CONFIG_FILE" ]; then \
		echo "Error: Config not found: $$CONFIG_FILE"; \
		echo ""; \
		echo "Available configs for $(TICKER):"; \
		ls $$BACKTEST_DIR/config/*.yaml 2>/dev/null | xargs -n 1 basename | sed 's|.yaml||' || echo "  (none)"; \
		exit 1; \
	fi; \
	echo "=========================================="; \
	echo "Running Backtest"; \
	echo "=========================================="; \
	echo "Ticker: $(TICKER)"; \
	echo "Config: $(CONFIG)"; \
	echo "Log:    $$LOG_FILE"; \
	echo "=========================================="; \
	echo ""; \
	cd "$$BACKTEST_DIR" && $(ABSPATH) run --config "config/$(CONFIG).yaml" 2>&1 | tee "reports/backtest_$(CONFIG).log"; \
	echo ""; \
	echo "=========================================="; \
	echo "Backtest Complete"; \
	echo "=========================================="; \
	echo "Reports in: $$BACKTEST_DIR/reports/"

backtest-all:
	@for ticker_dir in tickers/*/; do \
		ticker=$$(basename "$$ticker_dir"); \
		if [ -d "tickers/$$ticker/backtest/config" ]; then \
			echo ""; \
			echo ">>> Backtesting $$ticker..."; \
			$(MAKE) backtest TICKER=$$ticker CONFIG=$(CONFIG) || echo "  FAILED: $$ticker"; \
		fi; \
	done

# ──────────────────────────────────────────────
# Data Fetching
# ──────────────────────────────────────────────
fetch:
	@if [ -z "$(DAYS)" ]; then \
		echo "Error: DAYS parameter required."; \
		echo "Usage: make fetch TICKER=TQQQ START_DATE=2024-01-01 DAYS=90"; \
		echo "       make fetch TICKER=TQQQ START_DATE=2024-12-31 DAYS=-90"; \
		echo ""; \
		echo "Parameters:"; \
		echo "  TICKER     - Stock symbol (e.g., TQQQ, SPY)"; \
		echo "  START_DATE - Anchor date (YYYY-MM-DD)"; \
		echo "  DAYS       - Days offset (positive=forward, negative=backward)"; \
		echo ""; \
		echo "Examples:"; \
		echo "  make fetch TICKER=TQQQ START_DATE=2024-01-01 DAYS=90    # Jan 1 to Mar 31"; \
		echo "  make fetch TICKER=TQQQ START_DATE=2024-12-31 DAYS=-90   # Oct 2 to Dec 31"; \
		exit 1; \
	fi
	@if [ -z "$(START_DATE)" ]; then \
		echo "Error: START_DATE parameter required."; \
		echo "Usage: make fetch TICKER=TQQQ START_DATE=2024-01-01 DAYS=90"; \
		exit 1; \
	fi
	@echo "Creating folder structure for $(TICKER)..."
	@mkdir -p tickers/$(TICKER)/backtest/config
	@mkdir -p tickers/$(TICKER)/backtest/data
	@mkdir -p tickers/$(TICKER)/backtest/reports
	@mkdir -p tickers/$(TICKER)/live
	@echo "Fetching data for $(TICKER) from $(START_DATE), $(DAYS) days (port: $(PORT))..."
	@$(BOT) fetch \
		--symbol $(TICKER) \
		--start-date "$(START_DATE)" \
		--days $(DAYS) \
		--bar-size "1 min" \
		--port $(PORT) \
		--output "tickers/$(TICKER)/backtest/data/$(TICKER)_$(shell echo '$(START_DATE)' | tr -d '-')_$(DAYS)D_1m.csv"

fetch-futures:
	@if [ -z "$(MONTH)" ]; then \
		echo "Error: MONTH parameter required."; \
		echo "Usage: make fetch-futures TICKER=ES MONTH=202603 DAYS=90"; \
		exit 1; \
	fi
	@if [ -z "$(DAYS)" ]; then \
		echo "Error: DAYS parameter required."; \
		echo "Usage: make fetch-futures TICKER=ES MONTH=202603 DAYS=90"; \
		exit 1; \
	fi
	@echo "Creating folder structure for $(TICKER)..."
	@mkdir -p tickers/$(TICKER)/backtest/config
	@mkdir -p tickers/$(TICKER)/backtest/data
	@mkdir -p tickers/$(TICKER)/backtest/reports
	@mkdir -p tickers/$(TICKER)/live
	@echo "Fetching futures data for $(TICKER) (contract: $(MONTH)), $(DAYS) days..."
	@echo "Date range will be determined automatically based on contract expiry."
	@$(BOT) fetch \
		--symbol $(TICKER) \
		--sec-type FUT \
		--last-trade-month $(MONTH) \
		--duration "$(DAYS) D" \
		--bar-size "1 min" \
		--port $(PORT) \
		--output tickers/$(TICKER)/backtest/data/$(TICKER)_1m.csv

# ──────────────────────────────────────────────
# Analysis
# ──────────────────────────────────────────────
analyze-state:
	@STATE_FILE="tickers/$(TICKER)/live/state.json"; \
	if [ ! -f "$$STATE_FILE" ]; then \
		echo "Error: state.json not found for $(TICKER)"; \
		echo "Expected: $$STATE_FILE"; \
		echo "For paper trading, use: make analyze-state-paper TICKER=$(TICKER)"; \
		exit 1; \
	fi; \
	$(BOT) analyze-state "$$STATE_FILE"

analyze-state-paper:
	@STATE_FILE="tickers/$(TICKER)/live/paper_state.json"; \
	if [ ! -f "$$STATE_FILE" ]; then \
		echo "Error: paper_state.json not found for $(TICKER)"; \
		echo "Expected: $$STATE_FILE"; \
		echo "For live trading, use: make analyze-state TICKER=$(TICKER)"; \
		exit 1; \
	fi; \
	$(BOT) analyze-state "$$STATE_FILE"

analyze-state-backtest:
	@STATE_FILE="tickers/$(TICKER)/backtest/backtest_state.json"; \
	if [ ! -f "$$STATE_FILE" ]; then \
		echo "Error: backtest_state.json not found for $(TICKER)"; \
		echo "Expected: $$STATE_FILE"; \
		echo "Run 'make backtest TICKER=$(TICKER)' first."; \
		exit 1; \
	fi; \
	$(BOT) analyze-state "$$STATE_FILE"

analyze-report:
	@REPORT=$$(ls -t tickers/$(TICKER)/backtest/reports/*.txt 2>/dev/null | head -1); \
	if [ -z "$$REPORT" ]; then \
		echo "Error: No reports found for $(TICKER)"; \
		exit 1; \
	fi; \
	echo "Analyzing: $$REPORT"; \
	$(BOT) analyze-report "$$REPORT"

# ──────────────────────────────────────────────
# Logs & Maintenance
# ──────────────────────────────────────────────
logs:
	@LOG_FILE="tickers/$(TICKER)/live/trading.log"; \
	if [ ! -f "$$LOG_FILE" ]; then \
		echo "Error: No log file found for $(TICKER)"; \
		exit 1; \
	fi; \
	tail -f "$$LOG_FILE"

clean:
	@echo "Cleaning caches and temp files..."
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	@echo "Done."
