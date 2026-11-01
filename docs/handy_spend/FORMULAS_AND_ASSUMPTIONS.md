# Exact formulas and assumptions

- Balance(account, day) = opening balance if opening-as-of <= day + posted signed
  source movements - transfer fees + linked destination movements through that day.
- Expense = negative of posted expense/refund amounts + source-currency transfer
  fees. Income includes only income entries. Opening balances, corrections and
  transfer principal never become income/expense. Reports use [start, end).
- FX rate = destination major units per source major unit. Conversion uses BigInt
  numerator/denominator and rounds half away from zero to destination minor units.
  A transfer's target must match this calculation; same-currency principal matches.
- Safe to Spend = selected posted liquid balances + included future inflows - unpaid
  committed outflows - selected goal reserves - nonnegative minimum cash buffer.
  Positive per-day display floors to whole minor units over inclusive calendar days;
  actual negative availability and shortfall remain visible. Debts/locked savings
  are excluded by default. No heterogeneous currencies are summed.
- Conservative mode excludes future positive flows. Otherwise scheduled income
  must be explicitly marked reliable. Pending entries are user-entered assumptions.
  Future posted/pending/occurrence entries are counted once, not both as a bill and
  a payment. Transfers entirely within the selected currency/accounts net to zero.
- Forecast starts with today's posted balance, groups changes by reporting-zone
  calendar date, shows daily end balance, minimum and first negative day. No salary
  is invented. Overdue unpaid occurrences within 366 days are charged on start day;
  older unpaid schedules need manual review. Horizon limit: 3660 days.
- Monthly/yearly rules retain their original anchor and clamp shorter months.
  Weekends are not shifted automatically. DST uses IANA calendar dates, not 24-hour
  division. Historical anchors are fast-forwarded before bounded expansion.
- Budgets have explicit periods and currency/account/category scope. Optional
  rollover carries positive unused funds from one previous equal-length period;
  it is not an unlimited historical rollover chain.
- Installments divide the entered total exactly, remainder minor units assigned
  to early payments. No lender interest/fees are assumed. Sandbox keeps its saved
  baseline; explicit conversion is once per scenario, future payments stay pending.
- Recurring weekly/yearly equivalents use 52/12/1 payments; monthly run-rate is a
  rounded annual estimate divided by 12, not an issuer statement. Goal completion
  date is not inferred without a contribution schedule (P1 reverse planner).

These are user-data estimates, not financial advice or a guarantee. Reconcile manual
balances before making decisions. Engine regression tests are the executable spec.
