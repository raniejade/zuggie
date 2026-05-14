# Testing Patterns

## Test Pyramid

Tests are grouped into three tiers based on scope, dependencies, and expected duration.

| Tier   | Scope                                                        | Expected Duration |
|--------|--------------------------------------------------------------|-------------------|
| Small  | Single process, no I/O, exercises one unit in isolation      | Milliseconds      |
| Medium | Multi-process, localhost only, no external services          | Seconds           |
| Large  | Multi-machine, external services permitted, end-to-end flows | Minutes           |

Prefer small tests. Reach for medium when integration behavior must be verified. Reserve large tests for full system scenarios that cannot be decomposed.

---

## Arrange–Act–Assert

Every test function must follow this three-phase layout. No exceptions.

- **Arrange** — set up all preconditions: inputs, fakes, state, and configuration.
- **Act** — invoke exactly the one thing under test.
- **Assert** — verify the outcome; nothing else runs after the assertion.

Interleaving phases or asserting inside the Arrange block obscures the test's intent and makes failures harder to diagnose.

---

## DAMP over DRY

Rule: descriptive clarity in tests beats deduplication.

Extracting shared setup into helpers reduces lines but forces the reader to jump between methods to understand what state a test starts in. Prefer to repeat setup inline when repetition makes the test self-contained and readable at a glance.

```python
# Intentionally repeated — each test is understandable without reading helpers

def test_invoice_totals_vat_included():
    invoice = Invoice(items=[Item("widget", price=10.00)], vat_rate=0.20)
    total = invoice.total()
    assert total == 12.00

def test_invoice_totals_zero_vat():
    invoice = Invoice(items=[Item("widget", price=10.00)], vat_rate=0.00)
    total = invoice.total()
    assert total == 10.00
```

Both tests construct their own `Invoice` rather than sharing a factory call. A reader understands each test fully in isolation.

---

## Prove-It Pattern

Every bug fix must be accompanied by a test that proves the fix works. Follow these four steps in order:

1. Write a failing test that asserts the intended (correct) behavior. The test must target the exact scenario that the bug covers.
2. Run the test suite and confirm the new test is **RED** before any code change is made.
3. Apply the fix to the production code.
4. Run the test again and confirm it is **GREEN**, then run the full project test suite to confirm no regressions were introduced.

Skipping step 2 means the test may never have been capable of catching the bug.

---

## Anti-Patterns

- **Flaky tests** — tests that pass and fail non-deterministically erode trust in the suite and must be fixed or deleted immediately.
- **Snapshot overuse** — storing large serialized snapshots as expected values couples tests to incidental output details and makes legitimate changes painful.
- **Implementation-coupled assertions** — asserting on internal state, private methods, or call counts to internal collaborators ties tests to the implementation rather than the observable contract.
- **Excessive mocking** — replacing so many dependencies with fakes that the test no longer exercises any meaningful integration path; the subject under test effectively runs in a vacuum.

---

## Test Evidence

Every task that adds, modifies, or fixes behavior must include test evidence in its output. Evidence is not optional.

The three required fields are:

1. **Exact command run** — the verbatim shell command used to execute the tests, including any flags (e.g., `npm test`, `pytest tests/ -v`, `cargo test --workspace`).
2. **Brief outcome line** — a concise summary of the result (e.g., `"12 passed, 0 failed"`, `"all 47 tests green"`).
3. **For behavior changes — file path + test name + one-line intent** — when a test was added or modified to cover the change, state the relative path to the test file, the name of the test function or case, and a single line describing what behavior the test asserts.

Example:

```
Command: pytest tests/billing/test_invoice.py -v
Outcome: 14 passed, 0 failed
Test added: tests/billing/test_invoice.py :: test_invoice_totals_vat_included
Intent: asserts that VAT is included in the total when a non-zero rate is set
```

If no test was added or modified because the task is exempt (e.g., docs-only, config-only), declare the exemption explicitly with a reason.
