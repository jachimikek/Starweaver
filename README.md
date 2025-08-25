# Starweaver – Decentralized Prediction Markets & Oracle Network ✨🔮

## Description

**Starweaver** is a **sophisticated decentralized protocol** for creating and trading **prediction markets**, powered by a **trust-minimized oracle network**.
Users can create markets, trade YES/NO shares, oracles submit and validate real-world outcomes, and disputes ensure integrity through a staking and reputation system.

## Installation / Deployment

```sh
clarinet check
clarinet deploy
```

## Features

* **Prediction Markets** → Create and trade outcome shares with automated market making
* **Oracle Network** → Oracles stake tokens, submit outcomes, and earn resolution fees
* **Dispute Resolution** → Bonded challenges ensure data integrity and slashing for bad oracles
* **Liquidity System** → Built-in AMM for YES/NO shares with dynamic pricing
* **Trader Stats** → Reputation, ROI, and trading history tracked on-chain
* **Market Analytics** → Volume, price history, volatility, and unique traders per market
* **Configurable Governance** → Owner can update fees, dispute bond, oracle stake, and resolution windows

## Usage

### Market Lifecycle

* `create-market(title, description, category, resolve-time, resolution-source)` → Create a new market
* `buy-shares(market-id, position-type, max-cost)` → Buy YES/NO outcome shares
* `claim-winnings(market-id)` → Claim winnings once resolved

### Oracle System

* `register-oracle(specialization, fee-per-resolution)` → Register as oracle with stake
* `submit-oracle-result(oracle-id, market-id, outcome, confidence, evidence-hash)` → Submit outcome
* `resolve-market(market-id)` → Confirm market result after challenge window

### Disputes

* `dispute-oracle-result(market-id, reason, evidence)` → Challenge an oracle submission with bond

### Queries

* `get-market(market-id)` → Market details
* `get-market-price(market-id)` → Current YES probability (scaled 0–10000)
* `calculate-trade-price(market-id, position-type, shares)` → Estimated trade impact
* `get-position(market-id, trader)` → Trader position
* `estimate-payout(market-id, trader)` → Expected payout on resolution
* `get-platform-stats()` → Global stats (markets, volume, oracles, fees)
* `get-trader-stats(trader)` → Trader’s reputation, ROI, and activity

### Admin Controls

* `update-platform-parameters(platform-fee, min-oracle-stake, dispute-bond, resolution-period)`

---

🌌 **Starweaver: Trade the future. Secure the truth. Resolve with integrity.**
