# Lending & Borrowing Protocol

**A privacy-preserving, bilateral lending protocol built with Daml on the Canton Network.**

[![Daml SDK](https://img.shields.io/badge/Daml-3.4.11-0d4c92)](https://docs.daml.com/)
[![Canton Network](https://img.shields.io/badge/Canton-Network-1a56db)](https://www.canton.network/)
[![Tests](https://img.shields.io/badge/tests-19%20passing-2e8b57)](./daml/Test)

---

## Overview

Most on-chain lending protocols (Aave, Compound) pool liquidity into a shared contract whose state is globally visible — every position, every rate, every liquidation is public by construction. That's a hard requirement to relax on most chains, but it's a poor fit for institutional counterparties who don't want their positions visible to competitors.

Canton takes a different approach: contract state is only visible to a contract's signatories and observers, not the network at large. This project explores what a lending protocol looks like when built around that primitive instead of around a public pool — **matching individual lenders and borrowers into bilateral loans**, each visible only to its own participants.

## Protocol lifecycle

1. **Lenders** post a `LoanOffer` (amount, minimum rate). **Borrowers** post a `LoanRequest` (amount, max rate, collateral).
2. An **Operator** matches a compatible pair into a `Loan` — signed by just the Lender and Borrower. The Operator authorizes the match but is neither a signatory nor an observer on the resulting Loan.
3. Loans are overcollateralized. An **Oracle** publishes signed `Price` contracts; each Loan's Collateral Ratio is computed from the latest price.
4. Borrowers can **repay** (partially or in full) or **top up** collateral at any time.
5. If the Collateral Ratio drops below the liquidation threshold, an authorized **Liquidator** can **liquidate** the Loan — seizing collateral, taking a bonus, and making the Lender whole.

## Design highlights

A few decisions worth calling out:

- **The Operator never touches funds.** Matching a `LoanOffer` to a `LoanRequest` is a tri-party choice (`controller operator, lender, borrower`) — the Operator can authorize a match, but moving assets requires the Lender's and Borrower's own authority. This keeps the Operator's trust footprint to "can introduce counterparties," not "can move money."
- **No contract keys.** Daml 3.4's default ledger model (multi-domain Canton) doesn't support contract keys, which rules out the usual "supersede by key" pattern for the Oracle's `Price` feed. Instead, `Republish` is a consuming choice that atomically archives the old Price and creates the new one — same transaction, no window where two prices could coexist.
- **Interest accrues on demand, not on a schedule.** `Loan` doesn't tick on a timer; `outstandingBalanceAt` derives the current balance from `principal x rate x time elapsed` whenever a choice needs it (repay, liquidate), which sidesteps needing any kind of keeper/cron infrastructure.
- **Repayment without partial-transfer primitives.** There's no "split a Holding" choice — a Borrower repays by handing over a `Holding` of whatever amount they choose. A full-balance `Holding` closes the Loan; anything less mints a replacement `Loan` with the paid-down principal and a reset interest clock.

## Project structure

```
daml/
  Types.daml          AssetType (LoanAsset | CollateralAsset)
  Constants.daml      liquidationThreshold, liquidationBonus, secondsPerYear
  Holding.daml         Fungible asset contract (mint, transfer, lock)
  Price.daml           Oracle-published, signed asset prices
  LoanOffer.daml        Lender's standing offer to lend + Operator matching
  LoanRequest.daml      Borrower's standing request to borrow
  Loan.daml            The bilateral loan: repay, top-up, liquidate
  Test/                19 Daml Script scenarios covering the full lifecycle
daml.yaml              Daml SDK project config
```

## Getting started

Requires the [Daml SDK](https://docs.daml.com/getting-started/installation.html) (version pinned in `daml.yaml`).

```bash
daml build   # compile the project
daml test    # run all 19 Daml Script scenarios
```

## Test coverage

Every template has scripted, ledger-observable test coverage: minting and transfer visibility, Oracle publish/supersede/authorization, Offer/Request posting and cancellation, happy-path and under-collateralized matching, partial and full repayment, collateral top-up, and both healthy-loan and bad-debt liquidation paths.
