# ADR-0002: Gate model — two human STOPs, not one-at-the-end, not per-phase

**Status:** Accepted

**Context:** Where do humans gate an autonomous loop? The evidence splits: Spec Kit gates every
phase (artifact errors compound); Ralph runs iterations unattended (per-iteration review kills
autonomy). The first run also showed shipping without an independent human accept is unsafe.

**Decision:** Exactly **two human STOPs** — (1) after Plan/Analyze, before Build; (2) after
Verify, before Ship. Everything between (Build → Review → Verify) runs unattended on automated
gates. **Ship sits behind STOP #2.**

**Consequences:** Highest-leverage human minutes (plan review) and the irreversible-ish moment
(ship accept) are protected, while the mechanical middle stays autonomous. Not "build→verify→ship
then accept" (ship must be behind the accept); not a gate on every phase (Frame→Plan→Analyze flows;
build iterations flow).
