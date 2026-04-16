# Backend Testing

## Run

From `backend`:

```bash
pytest
```

## Scope

- isolated SQLite test database
- no live Stripe calls
- coverage for entitlements, pricing, checkout, portal, webhook processing, and scan reconcile flows

## Notes

- tests set their own `ENV=test` and `DATABASE_URL`
- Stripe interactions are mocked in the test suite
- startup migration checks are bypassed in tests so the suite can run against the isolated schema
