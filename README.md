# Shankz Trader - Customer: damz

A code-free client application template for Shankz Trader Bot. All functionality is provided by the installed `shankz-trader-bot` and `shankz-trader-lib` packages.

Run `make help` to see all available commands.

---

## Architecture

```
client-app-template
    ├── tickers/           # Per-ticker configuration and data
    │   ├── ES/
    │   │   ├── live/      # Live trading config, state, logs
    │   │   └── backtest/  # Backtest configs, data, reports
    │   └── MES/
    │       ├── live/
    │       └── backtest/
    ├── Makefile           # All operations via installed bot CLI
    └── pyproject.toml     # Bot/lib dependencies (installed from wheels)
```

**No Python code** is included in this template. All trading logic comes from the installed packages.

---

## Installation

### Standard Install (Pre-built Wheels)

```bash
export GITHUB_TOKEN=github_pat_...
make install
```

This downloads and installs `shankz-trader-bot` and `shankz-trader-lib` wheels from the private distribution repository.

### Development Install (Local Source)

```bash
USE_LIB_SOURCE=true make install
```

Installs from local `../shankz-trader-bot` and `../shankz-trader-lib` source directories (useful if you're developing the bot).

---

## Usage

### Live Trading

```bash
# Launch in foreground (Ctrl+C to stop)
make launch TICKER=ES

# Override IB port from config
make launch TICKER=ES PORT=4002

# Check all ticker status
make status

# Stop specific ticker
make stop TICKER=ES

# Stop all tickers
make stop-all
```

### Backtesting

```bash
# Run backtest
make backtest TICKER=ES CONFIG=default

# Run all tickers
make backtest-all CONFIG=default
```

### Data Fetching

```bash
# Fetch stock data
make fetch TICKER=SPY DAYS=30

# Fetch futures data
make fetch-futures TICKER=ES MONTH=202603 DAYS=90
```

### Analysis

```bash
# Analyze live state
make analyze-state TICKER=ES

# Analyze paper trading state
make analyze-state-paper TICKER=ES

# Analyze backtest state
make analyze-state-backtest TICKER=ES

# Analyze latest backtest report
make analyze-report TICKER=ES
```

---

## Strategy Filtering

To limit which strategies a client app can run, create `configs/strategies.yaml`:

```yaml
enabled_strategies:
  - DirectionTrigger
```

Then reference it in your ticker configs:

```yaml
# In tickers/ES/live/config.yaml or tickers/ES/backtest/config/default.yaml
strategies:
  - name: DirectionTrigger
    <<: *strategies_whitelist
```

Or use the CLI flag:

```bash
make launch TICKER=ES  # Uses all strategies from config
shankz-trader-bot run --config config.yaml --strategy DirectionTrigger  # Runs only DirectionTrigger
```

---

## Adding a New Ticker

```bash
cp -r tickers/ES tickers/MES
# Edit tickers/MES/live/config.yaml
# Edit tickers/MES/backtest/config/default.yaml
```

Key fields to change per instrument:

| Field | ES | MES | SPY |
|-------|-----|-----|-----|
| `symbol` | ES | MES | SPY |
| `sec_type` | FUT | FUT | STK |
| `exchange` | CME | CME | SMART |
| `point_value` | 50.0 | 5.0 | 1.0 |
| `tick_size` | 0.25 | 0.25 | 0.01 |

---

## IB Port Options

| Port | Connection |
|------|------------|
| 4001 | IB Gateway Live |
| 4002 | IB Gateway Paper |
| 7496 | TWS Live |
| 7497 | TWS Paper |

---

## Troubleshooting

**`make install` fails with "GITHUB_TOKEN is required"**

Export your token first: `export GITHUB_TOKEN=ghp_...`

**`make launch` says "already running"**

Check with `make status`. If it shows a stale PID, the old PID file will be cleaned up automatically on next launch.

**Backtest runs but produces no report**

Make sure you have data. Run `make fetch-futures TICKER=ES MONTH=202603 DAYS=90` first. Check that `tickers/ES/backtest/data/ES_1m.csv` exists and is not empty.

**"command not found: shankz-trader-bot"**

Run `make install` first. The bot is installed into `.venv/bin/`.

---

## Project Structure Details

```
tickers/
  ES/
    live/
      config.yaml          # Live trading config
      state.json           # Bot writes this at runtime
      paper_state.json     # Paper trading state
      trading.log          # Console output log
      abort                # Touch this file to stop gracefully
    backtest/
      config/
        default.yaml       # Backtest config(s)
        aggressive.yaml    # Additional configs
      data/
        ES_1m.csv          # Historical data (fetched via make fetch-futures)
      reports/
        backtest_default.log
        DirectionTrigger_*.txt
      state/
        backtest_state.json
```

You only edit the YAML configs. Everything else is generated at runtime.

---

## Maintenance

```bash
make clean    # removes __pycache__, .pyc, .egg-info
```

State files, logs, and data are not deleted by `make clean` -- remove them manually if needed.
