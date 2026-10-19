# Freqtrade research assessment

Assessed 19 October 2026. Local source is **Freqtrade 2026.9**, pinned to commit
`1f394eaebc2f46a83d26971388628707802f8602`. Version-specific statements below refer
to that commit; online stable documentation can move forward independently.

## Suitability

Freqtrade provides the core research loop: Python/pandas strategies, historical
market downloads, backtesting, parameter optimization with Hyperopt, and simulated
forward trading. It is a suitable research engine for the proposed workflow.
Its CLI also makes it practical to orchestrate reproducible experiments later.
This assessment does not establish that any strategy is profitable.
[Official project](https://github.com/freqtrade/freqtrade),
[feature documentation](https://www.freqtrade.io/en/stable/).

The official strategy collection is a sensible educational starting point. Its
maintainers explicitly describe examples as starting points rather than ready to
use strategies. Downloaded strategy files execute Python and need source review
before importing or running them.
[Official strategy collection](https://github.com/freqtrade/freqtrade-strategies).

## OKX demo and dry-run are separate stages

Freqtrade dry-run simulates orders locally while consuming exchange prices. It
does not place orders in an OKX demo account. The current research configuration
should use dry-run and blank credentials.
[Dry-run configuration](https://www.freqtrade.io/en/stable/configuration/#using-dry-run-mode).

OKX itself supports demo API trading with separate demo credentials and the
`x-simulated-trading: 1` request header. Its REST host can be shared with production,
so a hostname alone is not proof of simulated routing. Demo WebSocket endpoints
are separate. Some account operations, including deposits and withdrawals, are
unavailable in demo.
[OKX API documentation](https://www.okx.com/docs-v5/en/#overview-demo-trading-services).

Existing OKX subaccounts can be used in demo. Create/manage the subaccount in the
live environment first, then switch the selected subaccount to demo; creating
subaccounts inside demo is not supported. Availability must be checked for the
user's account and region.
[OKX demo help](https://www.okx.com/en-us/help/how-to-use-demo-trading).

**Freqtrade 2026.9 has no native OKX demo toggle.** At the pinned commit:

- `Exchange.validate_demo_trading()` rejects `exchange.demo_trading: true` unless
  `supports_demo_trading` is enabled.
- CCXT's `enable_demo_trading(True)` is invoked only when that capability is enabled.
- `Okx` does not declare that capability.

These are source-level findings, not merely missing documentation:
[pinned Exchange implementation](https://github.com/freqtrade/freqtrade/blob/1f394eaebc2f46a83d26971388628707802f8602/freqtrade/exchange/exchange.py#L930),
[pinned OKX implementation](https://github.com/freqtrade/freqtrade/blob/1f394eaebc2f46a83d26971388628707802f8602/freqtrade/exchange/okx.py#L25).
Do not copy Bybit's demo option or rely on old Freqtrade `sandbox: true` tutorials.

CCXT's OKX implementation provides `set_sandbox_mode()`, which enables the
simulated-trading header and sandbox options. **Inference:** a dedicated integration
or carefully verified custom configuration may bridge the gap. This has not been
implemented or validated here and is not a claim of supported Freqtrade behavior.
Before incubation, verify the installed CCXT version, REST and WebSocket routing,
demo-only authentication, balances, order creation/cancellation, stop orders and
restart reconciliation. Use demo-only credentials in that integration.
[CCXT OKX source](https://github.com/ccxt/ccxt/blob/master/python/ccxt/okx.py).

## Market and backtest limitations

The pinned OKX class supports spot and isolated futures; cross futures and margin
are not enabled. Its candle-limit implementation permits 300 regular spot/futures
candles per request and treats other candle types separately. A per-request candle
limit is not a limit on the total history downloaded through pagination.
[Pinned OKX source](https://github.com/freqtrade/freqtrade/blob/1f394eaebc2f46a83d26971388628707802f8602/freqtrade/exchange/okx.py#L53).

Current official exchange notes warn that OKX mark candles cover roughly the last
three months, affecting funding calculations on older futures backtests. They also
distinguish `okx` from `myokx` for the EEA entity. Verify the account's actual entity;
the computer's timezone does not establish it. Spot is the recommended first
tutorial because it avoids funding and leverage mechanics.
[OKX exchange notes](https://www.freqtrade.io/en/stable/exchanges/#okx).

Backtesting assumes fills without slippage when prices are within a candle's range;
intrabar sequencing is approximate. Lower timeframe detail improves resolution but
does not reproduce live execution. Historical precision and trading limits are
also imperfect. Use conservative fees and additional execution-cost stress tests.
Backtest ZIPs preserve the strategy, parameters, sanitized configuration and report;
archive the underlying data, dependency versions and source commit separately.
[Backtesting documentation](https://www.freqtrade.io/en/stable/backtesting/).

## Recommended research gates

1. Choose a small, liquid spot universe and a transparent baseline strategy.
2. Download production-market history without private API credentials. Record
   exchange, pairs, dates, timeframes and gaps.
3. Freeze chronological training, validation and untouched test periods. Run a
   baseline before optimizing.
4. Run lookahead analysis and inspect signal coverage. A passing result only
   covers signals exercised by its tests; untriggered branches can conceal bias.
   [Lookahead analysis](https://www.freqtrade.io/en/stable/lookahead-analysis/).
5. Run recursive analysis to choose adequate indicator startup history. It compares
   indicator values at the last row; it does not certify trading behavior.
   [Recursive analysis](https://www.freqtrade.io/en/stable/recursive-analysis/).
6. Hyperopt only training data with a bounded search budget, appropriate loss and
   minimum trade count. Freeze candidate parameters before validation/test runs.
   [Hyperopt documentation](https://www.freqtrade.io/en/stable/hyperopt/).
7. Evaluate drawdown, trade count, profit concentration, market regimes and
   neighboring parameter values; compare a simple benchmark. Avoid selecting by
   headline return alone. Repeatedly inspecting the test set makes it part of
   model selection; reserve fresh data when that happens.
8. Forward-test with Freqtrade dry-run, then use the separately verified OKX demo
   integration. Define pass/fail thresholds and incubation duration before
   observing results. Real execution remains a separate future decision.

Steps concerning dataset splits, selection discipline, benchmarks and promotion
thresholds are research-design recommendations, not built-in Freqtrade guarantees.

## Isolation and future Hermes orchestration

The user requires Docker or VM isolation. The prepared Docker workflow uses a
pinned image, a named data volume, read-only research inputs, an unprivileged user,
dropped capabilities and `no-new-privileges`. It exposes no ports and mounts no
Docker socket or home directory. These are local workflow design choices, not
claims about upstream defaults. Verify the actual Compose configuration and runtime
before executing candidate code.

A container sharing the host kernel is not a complete adversarial sandbox.
Downloaded or agent-generated strategies should eventually run in their own
stronger isolated environment, such as a disposable VM with restricted egress,
resource limits and no exchange secrets. Research agents should receive only the
data and artifacts needed for their stage.

Recommended future Hermes roles are discovery/source review, dataset preparation,
experiment execution, independent validation, and report/promotion review. Keep a
manifest per run: candidate source URL and commit/hash, license, strategy and
configuration hashes, runtime version, dataset identity, splits, seed, search
budget, logs and reports. Give agents bounded jobs and require independent
validation before promotion. These are recommendations; no agent automation has
been enabled by this setup.

Keep credentials out of model prompts, source control and research containers.
OKX's agent guidance recommends dedicated subaccounts and minimum API permissions.
[OKX Agent Trade Kit guidance](https://www.okx.com/docs-v5/agent_en/).

## Moving winners to a cloud bot platform

The target platform is not yet specified. **Inference:** a platform that runs
Freqtrade containers can preserve the implementation; a platform using another
strategy language or signal model will usually require a port or execution bridge.
Compare candle timing, indicator initialization, entries/exits, sizing, fees,
stop/ROI/trailing behavior and restart state with shared test vectors before
claiming parity.

Freqtrade webhooks can send configured trade lifecycle events. They do not
automatically translate Python strategies or guarantee another platform's fill and
risk behavior. Decide the target platform before depending on features it cannot
reproduce.
[Webhook documentation](https://www.freqtrade.io/en/stable/webhook-config/).
