# Lending & Borrowing Protocol — Spec

## Problem Statement

I want to practice building demo code on the Canton network, and a lending/borrowing protocol is a good vehicle for it — but I can't just port Aave's design over. Aave relies on a shared liquidity pool with globally-visible state (total supply, utilization, borrow index), and Canton's core guarantee is that contract state is only ever visible to signatories and observers. There is no way to see "the pool" the way you can on a stateless global chain. I need a lending protocol whose design actually respects Canton's privacy model instead of fighting it.

## Solution

A bilateral, privacy-preserving lending protocol: Lenders and Borrowers are matched by an Operator into direct Loan contracts between exactly one Lender and one Borrower, instead of pooling liquidity. Each Loan is overcollateralized and tracked against a trusted Oracle's price feed, with an incentivized Liquidator role able to close out undercollateralized positions. Every contract is visible only to the parties who need to see it — the Operator matches offers to requests but does not remain attached to (or visible on) the resulting Loan. The deliverable is a Daml model (templates, choices, authorization) proven correct via Daml Script scenarios — no UI or backend app.

## User Stories

1. As a Lender, I want to post a Loan Offer specifying an amount of the Loan Asset and a minimum acceptable rate, so that the Operator can match me with a Borrower.
2. As a Lender, I want to cancel my own unmatched Loan Offer at any time, so that I can withdraw from the market if my terms are no longer attractive.
3. As a Lender, I want my Loan Offer to only be visible to me and the Operator, so that my available liquidity isn't exposed to other participants.
4. As a Borrower, I want to post a Loan Request specifying an amount of the Loan Asset I want to borrow, the Collateral Asset and amount I'm posting, and a maximum acceptable rate, so that the Operator can match me with a Lender.
5. As a Borrower, I want to cancel my own unmatched Loan Request at any time, so that I can adjust my terms or back out before being matched.
6. As a Borrower, I want my Loan Request to only be visible to me and the Operator, so that my borrowing intentions aren't exposed to other participants.
7. As a Borrower, I want my Loan Request to be rejected (or simply unmatchable) if my posted collateral doesn't meet the Liquidation Threshold at the Loan Asset amount I'm requesting, so that I can never originate an already-undercollateralized Loan.
8. As the Operator, I want to match a Loan Offer to a Loan Request only when their amounts are exactly equal, their asset types are compatible (matching Loan Asset), and the Borrower's max rate meets or exceeds the Lender's min rate, so that both sides' terms are honored.
9. As the Operator, I want a match to produce a single fixed interest rate (drawn from within the Lender's min / Borrower's max range) that is locked into the resulting Loan for its lifetime, so that neither party is exposed to unexpected rate changes later.
10. As the Operator, I want my authority to end once a Loan is created — I should not remain a signatory or observer on the Loan — so that ongoing positions stay private between the Lender, Borrower, and whichever of Oracle/Liquidator need visibility.
11. As the Operator, I want to never hold or custody either party's assets at any point in the matching process, so that the protocol has no pooled-liquidity failure mode.
12. As a Lender, once matched, I want my Loan Asset holding to be transferred to the Borrower as part of Loan creation, so that the Borrower actually receives the funds they requested.
13. As a Borrower, once matched, I want my posted Collateral Asset holding to be locked into the Loan as part of its creation, so that the Lender (and later, a Liquidator) has recourse against it.
14. As a Lender, I want to see the current Outstanding Balance (Principal + Accrued Interest) on my Loan at any time, so that I know what I'm owed.
15. As a Borrower, I want Accrued Interest to be computed on demand (principal x rate x time elapsed since the last update) rather than requiring periodic payments, so that I only need to act when I choose to repay or top up collateral.
16. As a Borrower, I want to make a partial repayment of any amount up to my full Outstanding Balance, so that I can pay down debt and improve my Collateral Ratio without fully closing the Loan.
17. As a Borrower, I want a full repayment of my Outstanding Balance to close the Loan and release all remaining collateral back to me, so that I can exit my position cleanly.
18. As a Borrower, I want to lock additional Collateral Asset into an existing Loan at any time, so that I can improve my Collateral Ratio and defend against Liquidation without repaying principal.
19. As the Oracle, I want to publish a signed Price contract for the Loan Asset and for the Collateral Asset, so that any Loan can compute its current Collateral Ratio.
20. As any party computing it, I want the Collateral Ratio to be defined as (collateral amount x Collateral Asset price) / (outstanding balance x Loan Asset price), so that it reflects the current market value of both sides of the position.
21. As a Liquidator, I want to be able to exercise Liquidate on a Loan whenever its Collateral Ratio has fallen below the Liquidation Threshold, so that undercollateralized positions get closed out promptly.
22. As a Liquidator, when I liquidate a Loan, I want to receive a fixed bonus percentage of the seized collateral, so that I'm economically incentivized to monitor and act on undercollateralized positions.
23. As a Lender, when my Loan is liquidated, I want to receive the seized collateral (minus the Liquidator's bonus) up to my Outstanding Balance, so that I recover as much of my position as the collateral allows — even if that's less than what I'm owed.
24. As a Liquidator, I want Liquidation to always fully close the Loan (not partially), so that the mechanic stays simple: seize all remaining collateral, pay the bonus, cover the Lender, archive the Loan.
25. As the protocol, I want the Liquidation Threshold to double as both the minimum Collateral Ratio required to originate a Loan Request and the trigger point for Liquidation, so that there's a single, simple, well-understood number governing collateral safety.
26. As the protocol, I want the Liquidation Threshold and Liquidation Bonus to be hardcoded constants (not configurable per-loan or via a governance contract), so that the model stays focused on lending mechanics rather than protocol governance.
27. As the protocol, I want exactly two fixed asset types — a Loan Asset and a Collateral Asset — represented as self-contained Holding contracts (owner, issuer, amount, asset type), so that the Collateral Ratio and Oracle price feed are meaningful without needing a generalized multi-asset registry.
28. As a developer verifying the model, I want a Daml Script scenario covering the full happy path (offer, request, match, partial repay, top-up, full repay), so that I can confirm the core lifecycle works end-to-end.
29. As a developer verifying the model, I want a Daml Script scenario that drives a Loan into Liquidation via a price drop and confirms collateral is distributed correctly (bonus to Liquidator, remainder to Lender), so that the liquidation path is proven correct.
30. As a developer verifying the model, I want Daml Script scenarios that assert on contract *visibility* (e.g. a non-party cannot see a Loan; the Operator cannot see a Loan after matching), so that the privacy properties this whole design exists for are actually verified, not just assumed.

## Implementation Decisions

- **Parties/roles**: Lender, Borrower, Operator, Oracle, Liquidator. Multiple Lenders/Borrowers/Liquidators may exist; a single Operator and single Oracle are sufficient for the demo (see [[grilling]] session and `CONTEXT.md`).
- **Matching model**: Operator-mediated, exact-amount matching only (no partial fills, no splitting of Offers/Requests). See ADR 0001.
- **Loan authorization**: Loan is signed by Lender and Borrower only. The Operator's authority is scoped to the choice that creates the Loan from a matched Offer + Request; it is not a continuing signatory or observer. Oracle and Liquidator are granted the visibility they need (e.g. as observers) to do their jobs. See ADR 0003.
- **Rate**: Fixed at match time, chosen from within [Lender's min rate, Borrower's max rate], stored on the Loan and immutable thereafter.
- **Term**: Open-ended — no maturity date. Loan only closes via full repayment or Liquidation.
- **Interest**: Computed on demand (principal x rate x time elapsed since last update), not via periodic payment choices. Requires tracking principal and a last-updated timestamp on the Loan.
- **Repayment**: Partial repayment supported — any amount up to the current Outstanding Balance. Reduces principal (and thus improves Collateral Ratio). Full repayment archives the Loan and releases all collateral.
- **Collateral top-up**: Separate choice, lets the Borrower lock additional Collateral Asset into an existing Loan at any time.
- **Collateral thresholds**: Single Liquidation Threshold, hardcoded, reused both as the minimum ratio required to originate a Loan Request and as the Liquidation trigger. No separate initial-LTV/liquidation-threshold split.
- **Liquidation**: Full liquidation only (no partial/close-factor liquidation). Seizes all remaining collateral; pays a hardcoded bonus percentage to the Liquidator; remainder goes to the Lender up to the Outstanding Balance. Bad debt (collateral insufficient to cover the Outstanding Balance) is absorbed by the Lender — no insurance/safety module.
- **Asset model**: Self-contained custom Holding contract (owner, issuer, amount, asset type) — not the Canton Network Token Standard. See ADR 0002.
- **Asset variety**: Exactly two fixed asset types for the demo — one Loan Asset (stable) and one Collateral Asset (volatile).
- **Oracle**: Single trusted party publishing signed Price contracts per asset type. Loans read the latest Price to compute Collateral Ratio on demand (no push-based recalculation).
- **Offer/Request lifecycle**: Loan Offer and Loan Request are cancellable by their creator at any time before matching. No expiry mechanism.
- **Domain vocabulary**: Use the terms defined in `CONTEXT.md` throughout (Lender, Borrower, Operator, Oracle, Liquidator, Loan Offer, Loan Request, Loan, Collateral Ratio, Price, Liquidation, Liquidation Threshold, Principal, Outstanding Balance, Accrued Interest, Loan Asset, Collateral Asset, Holding). Avoid "pool," "keeper," "depositor," "debtor" per the glossary's `_Avoid_` entries.
- **Relevant ADRs**: `docs/adr/0001-bilateral-operator-matched-loans.md`, `docs/adr/0002-self-contained-asset-model.md`, `docs/adr/0003-operator-scoped-to-matching.md`.

## Testing Decisions

- **Seam**: Daml Script end-to-end scenarios are the single testing seam for this feature. Every scenario submits transactions as a specific party (Lender, Borrower, Operator, Oracle, or Liquidator), exercises a choice, and asserts on the resulting ledger state — never testing internal functions or formulas in isolation from the ledger.
- **What makes a good test here**: assert on externally observable outcomes — contract creation/archival, resulting Holding balances, computed Collateral Ratio/Outstanding Balance values, and *who can see what* (a core property of this design, per ADR 0001 and 0003). Do not assert on internal implementation details that aren't observable via the ledger API (e.g. don't test a private helper function directly — drive it through a choice and check the resulting contract state).
- **Scenarios to cover** (mirrors the user stories above): full happy path (offer → request → match → partial repay → top-up → full repay); cancellation of an unmatched Offer/Request; a Loan Request that fails to meet the Liquidation Threshold at origination; a full liquidation flow (price drop → Liquidate → bonus to Liquidator, remainder to Lender, Loan archived); a bad-debt liquidation (collateral insufficient to cover Outstanding Balance, Lender absorbs shortfall); visibility assertions (non-party cannot see a Loan; Operator cannot see a Loan post-match; Lender/Borrower can each see their own Loan).
- **Prior art**: None — this is a from-scratch project with no existing test suite to follow conventions from.

## Out of Scope

- Any UI, frontend, or backend application layer — this spec covers the Daml model only.
- The Canton Network Token Standard / interoperability with real token implementations (ADR 0002).
- Variable/algorithmic interest rates that change over the life of a Loan.
- Fixed-term loans with maturity dates.
- Partial matching / splitting of Loan Offers or Requests across multiple Loans.
- Partial liquidation (close-factor style).
- More than two asset types, or a generalized asset registry.
- Configurable/governed protocol parameters (Liquidation Threshold, Liquidation Bonus) — these are hardcoded constants.
- A protocol insurance/safety module to cover bad debt.
- Multiple Oracles or price consensus/aggregation.
- Expiry of unmatched Loan Offers/Requests.

## Further Notes

- This spec was produced from a `/grilling` session (using `/domain-modeling`) against `docs/docs-for-ai/idea.md`, the original one-line pitch: build a Canton/Daml lending-and-borrowing protocol that's deliberately not Aave's pooled model, because Canton's privacy rules don't support globally-visible pool state.
- This repo is not yet a git repository and has no issue tracker configured, so this spec was written to `docs/spec-lending-protocol.md` rather than published to a tracker with a `ready-for-agent` label. If an issue tracker is set up later (e.g. via `/setup-matt-pocock-skills`), this file's content should be moved there.
- `CONTEXT.md` (glossary) and `docs/adr/0001`–`0003` should be treated as living alongside this spec — if implementation surfaces a need to deviate from a decision recorded there, update the source of truth, don't let this spec silently drift from it.
