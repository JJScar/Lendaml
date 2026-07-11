# Lending & Borrowing Protocol (Daml)

A privacy-preserving lending and borrowing protocol on the Canton network, built with Daml. Unlike Aave's pooled-liquidity model (which relies on globally-visible contract state), this protocol matches individual lenders and borrowers into bilateral loans, since Canton only reveals contract state to signatories and observers.

## How it works

- **Lenders** post a **Loan Offer** (amount, minimum rate); **Borrowers** post a **Loan Request** (amount, max rate, collateral).
- An **Operator** matches a compatible Offer/Request pair into a **Loan** — a bilateral contract between exactly one Lender and one Borrower. The Operator never custodies funds; it only pairs counterparties.
- Loans are overcollateralized. An **Oracle** publishes signed **Price** contracts used to compute each Loan's Collateral Ratio.
- Borrowers can partially or fully **repay**, or **top up** collateral. If the Collateral Ratio falls below the liquidation threshold, a **Liquidator** can **liquidate** the Loan, seizing collateral (minus a bonus) to make the Lender whole.

## Project structure

```
daml/
  Types.daml        AssetType (LoanAsset | CollateralAsset)
  Constants.daml     liquidationThreshold, liquidationBonus, secondsPerYear
  Holding.daml       Fungible asset contract (mint, transfer, lock)
  Price.daml         Oracle-published, signed asset prices
  LoanOffer.daml      Lender's standing offer to lend + Operator matching
  LoanRequest.daml    Borrower's standing request to borrow
  Loan.daml          The bilateral loan: repay, top-up, liquidate
  Test/              Daml Script test scenarios, one module per template
daml.yaml            Daml SDK project config
```

## Building and testing

Requires the [Daml SDK](https://docs.daml.com/getting-started/installation.html) (see `sdk-version` in `daml.yaml`).

```bash
daml build   # compile the project
daml test    # run all Daml Script test scenarios
```

## Status

All planned tickets are implemented and passing: Holdings (mint/transfer), Oracle Price publishing, Loan Offer/Request post & cancel, Operator matching, partial/full repayment, collateral top-up, and liquidation.
