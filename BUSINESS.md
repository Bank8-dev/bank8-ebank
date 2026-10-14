# BUSINESS.md: Bank8:eBank — Business Requirements & Functionality

> Audience: product owners, business analysts, and anyone evaluating what
> Bank8:eBank **does for the business**. For architecture read `README.md`;
> for wire-level detail read `DESIGN.md`.

## 1. Business Purpose

- Give retail customers a complete self-service digital banking channel:
  onboarding, account opening, balances, transactions, transfers, statements,
  and notifications.
- Serve as the **customer-facing side of open banking**: the customer grants
  and revokes FDX data-sharing consent for external fintech providers from
  inside their own bank app.
- Keep every credential, token, and byte of tenant data under platform
  control — the app itself carries nothing sensitive.

## 2. Business Scope (What the Service Provides)

| Capability | Delivered through |
|---|---|
| Customer sign-up / sign-in via hosted identity UI | Sentin8:Auth (BFF-brokered) |
| Product catalog browsing (13 ledger products) | Bank8:Ledger |
| Account opening (current, savings, US checking/savings, Shariah savings, time deposit, loan, credit card, mortgage, line of credit, wallet, BNPL, home-loan redraw) | Bank8:Ledger |
| Balances and transaction history (paged) | Bank8:Ledger |
| Internal transfers between own accounts | Bank8:Ledger postings |
| External payments & payee history view | Bank8:Payments |
| Statement list and secure download | Bank8:Ledger + storage signed URLs |
| In-app notification inbox with unread indicator | post + SSE |
| FDX consent review and revocation (customer side) | Bank8:FDX |
| Instance admin overview (staff) | runtime context |
| Product activation & parameter overrides (staff) | Bank8:Ledger |
| FDX provider profile, recipient registry, consent monitoring (staff) | Bank8:FDX |

**What eBank does NOT own (business boundary):**

| Concern | Owning service |
|---|---|
| Identity, consent issuance, hosted sign-in | Sentin8:Auth |
| Financial truth (balances, postings, products) | Bank8:Ledger |
| Payment orchestration, limits, risk | Bank8:Payments |
| FDX provider gateway, consent enforcement, data minimization | Bank8:FDX |
| Session/token custody | Sentin8:BFF |
| Structured persistence | Sentin8:DB |
| Statement/document bytes | storage |
| Notifications fan-out | post |

## 3. Business Capabilities

| Area | Capability | Business rule |
|---|---|---|
| Onboarding | Customer provisioning | A signed-in subject is linked to exactly one ledger customer per environment; replays never duplicate it. |
| Deposits | Account opening | A customer may open any catalog product they are eligible for; the account appears immediately in the dashboard. |
| Servicing | Balances & transactions | A customer sees only their own accounts; internal bank plumbing accounts are invisible. |
| Transfers | Money movement | Every transfer is idempotent — a retried submission can never double-post. |
| Payments | External payment visibility | Customers see payments and payees recorded by the payment engine; they cannot corrupt payment state. |
| Statements | Document access | Statements download through short-lived signed URLs only. |
| Open banking (customer) | Consent control | The customer can list every active data-sharing consent and revoke any of them instantly. |
| Open banking (staff) | Provider administration | Staff manage the provider profile, review registered external recipients, and monitor consent activity. |
| Admin | Product lifecycle | Staff activate/deactivate ledger products and override default parameters per environment; every change is audited upstream. |

## 4. Business Events (Outbound)

eBank emits no domain events of its own (it is a pure presentation layer).
Business events the app triggers *upstream* by performing operations:

| Operation in app | Upstream event fired by the owning service |
|---|---|
| Transfer / account opening / customer provisioning | Ledger posting & account events (Bank8:Ledger) |
| Consent revocation | FDX consent lifecycle event (Bank8:FDX) |
| Product activation / override (staff) | Ledger product event (Bank8:Ledger) |

**Inbound (consumed):** notification events delivered over SSE
(`sentin8:notification.received`, `sentin8:notification.read`) — used to keep
the inbox unread badge live.

## 5. Business Rules & Invariants

1. No credential, token, or refresh token ever reaches the customer client.
2. A customer sees only their own accounts (internal bank accounts are never
   exposed to the customer surface).
3. Every money movement is idempotent — retries cannot double-post.
4. A customer can always see and revoke every consent sharing their data.
5. Admin pages are staff-only; customers cannot reach them (enforced by the
   BFF, not just hidden in the UI).
6. Statement bytes leave storage only through signed, short-lived URLs.
7. The app fails closed: without a verified instance identity no page loads.

## 6. Target-User Roles & Use Cases

| Persona | What they do |
|---|---|
| Retail customer | Signs up, opens products, checks balances, transfers, downloads statements, manages notification inbox, grants/revokes FDX consents. |
| Bank staff (admin surface) | Monitors instance status, activates ledger products and overrides parameters, oversees FDX provider profile and registered recipients. |
| Product owner | Measures adoption of self-service banking and consent-management flows. |

## 7. KPIs / Success Criteria

- **Reliability:** fail-closed bootstrap with zero cross-tenant incidents;
  transfer success rate on first submission.
- **Latency:** dashboard and account-detail loads perceived as instant under
  normal network conditions (proxy round-trip only, no extra hops).
- **Security:** zero token exposure incidents; 100% of admin mutations
  audited upstream.
- **UX quality:** uniform loading/error frames across all pages; live unread
  badge without page refresh.
- **Open banking:** consent revocation is instant and always discoverable by
  the customer.

## 8. Dependencies & Reliance on Other Services

| Dependency | Why |
|---|---|
| Sentin8:Auth | All sign-in/sign-up; consent UI for provider flows |
| Sentin8:BFF | Session custody, token attach, scope gating, proxy |
| Bank8:Ledger | Products, accounts, balances, postings, statements, customers |
| Bank8:Payments | Payments and payee history |
| Bank8:FDX | Consent surfaces, provider profile, recipients |
| Sentin8:App | Instance provisioning, runtime context, listing |
| Sentin8:Bus + post | Notification fan-out to the SSE stream |
| Sentin8:TLS | Hostname → instance resolution, TLS termination |

## 9. Acceptance Criteria

1. A new customer can sign up through the hosted identity UI and land in a
   working dashboard without any manual backend step.
2. Customer can open any catalog product and see it immediately.
3. Customer can transfer between own accounts; a retried transfer never
   double-posts.
4. Customer can download statements securely (signed URL, no cached file).
5. Customer can view and revoke FDX consents; revocation takes effect
   immediately for the recipient.
6. Staff can act on the admin surface and their actions are gated by staff
   authorization upstream.
7. No page ever loads without verified instance context (fail closed).
8. E2E journeys (sign-up → account opening → transfer → statements → consent)
   run through the browser only, exactly like a real user.

## 10. Open Business Questions

- Should customers be able to initiate external (cross-bank) payments from
  eBank, or remain read-only on payment history today?
- Should statement delivery also be push-based (notification with deep link)
  in addition to in-app listing?

---

**Design attribution:** bank8:ebank and its underlying concepts were designed by Hamid Jahanzad <Hamid@Jahanzad.com>.
