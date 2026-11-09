# R1 (CVE-2026-47101) reach investigation — review 2 P1/P4 (2026-11-09)

On v1.83.13-nightly (R1 affected per advisory), with an internal_user:

- **Explicit `allowed_routes` is blocked at mint** (403): "Only proxy admins can set `allowed_routes`
  on a key. Use `key_type` to pick a preset route bucket instead." The guard
  `_check_allowed_routes_caller_permission` is present from v1.83.7-stable (check count: 1.83.6=0,
  1.83.7=3, 1.83.13=3, 1.83.14=7), so the explicit-route vector is already closed well before 1.83.14.
- **`key_type=management` mint succeeds** → child key allowed_routes=["management_routes"], user_role=null.
  But that child key reaches **no** admin-only route: every sensitive management route has an
  endpoint-level role check that the route-gate bypass does not defeat, e.g.
  POST /user/new → 401 "Only proxy admin can be used to generate, delete, update info for new
  keys/users/teams. Route=/user/new. Your role=internal_user." GET /user/list → 403 "Only proxy admins
  and organization admins can list users." The child is in fact MORE restricted than the plain
  internal_user key (allowed_routes is a whitelist), so there is no (plain-blocked, child-2xx) route.

**Conclusion:** the advisory's impact — a non-admin key *reaching* an admin-only route with 2xx — is
**not reproducible on the 1.83.13→1.83.14 ladder with mock providers**. The only observable 13→14
change is the key_type mint flipping 200→403 (defense-in-depth), which is NOT the frozen G13 signature
(reach 2xx). Per the KC1 D4/D6 rule and review-2 P1, **R1 is recorded INVALID / not-rediscovered**, not
a FAIL→PASS flip. Recall therefore rests on R2, R3, R4 (+ R5 if built).

Routes probed on the mgmt child (plain internal_user vs child, http): /user/list 403/403, /team/list
401/401, /organization/list 200/403, /key/list 200/200, /spend/logs 200/200, /user/new 401/401,
/team/new 401/401, /organization/new 401/401, /model/new 403/403, /global/spend/report 400/403,
/cache/delete 401/401, /cache/ping 401/401, /model/delete 400/400, /model/info 200/200,
/cache/flushall 401/401, /active/callbacks 401/401, /settings 401/401. None show child-2xx where plain is blocked.
