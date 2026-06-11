# Mutation testing decision

**Decision: rely on BATS + shellcheck as the gate; do NOT add bash mutation testing.**

The mutation-testing ecosystem (Stryker, mutmut, PITest) targets TypeScript, Python, and JVM
languages. No production-grade bash mutation tool exists that integrates cleanly with BATS.
Hand-rolling a sed-mutant-in-BATS approach (comment out lines, swap operators, re-run suite)
adds maintenance overhead without a significant confidence gain: shellcheck already catches
dead-code and logic errors statically, and BATS tests cover the observable exit-code and
output contracts that matter. The test suite currently achieves 248/248 passing with shellcheck
clean on all hooks. That is the appropriate bar for a bash orchestration tool of this scope.
