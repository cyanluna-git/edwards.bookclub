# Bookclub Direct Entra ID SSO Request

## Goal

Add direct Microsoft Entra ID SSO to the `edwards.bookclub` Rails application.

This app should authenticate against Entra ID directly.
Do not reuse the `oqc` application's JWT, localStorage session, or frontend token flow.

## Why

The current `bookclub` app uses local email/password login with Rails session cookies.
That works for development, but production should use the same corporate identity provider as other internal services.

Direct Entra ID integration is preferred over redirecting through another internal app because:

- It keeps authentication ownership inside `bookclub`
- It avoids tight coupling to `oqc` implementation details
- It reduces failure domains between services
- It is easier to maintain long-term

## Current App State

Relevant current files:

- `app/controllers/sessions_controller.rb`
- `app/controllers/application_controller.rb`
- `app/models/user.rb`
- `config/routes.rb`

Current behavior:

- local sign-in form
- password-based authentication using `has_secure_password`
- Rails cookie session via `session[:user_id]`
- authorization based on existing `users` table and linked `members`

## Requested Direction

Implement **direct Entra ID SSO** for `bookclub`.

Preferred protocol:

- `OIDC` preferred
- `SAML` acceptable only if OIDC is blocked by infrastructure constraints

## Required Behavior

### 1. Login Entry

Add an SSO login option on the sign-in page.

Expected UX:

- User opens `bookclub`
- If not authenticated, they can choose `Sign in with Microsoft`
- App redirects to Microsoft Entra ID
- After successful login, app returns to `bookclub`
- `bookclub` creates its own Rails session cookie

### 2. User Mapping

After successful Entra authentication, map the corporate identity to an existing local `User`.

Preferred mapping key:

- primary: email address claim from Entra ID

Expected behavior:

- if matching `User.email` exists, sign that user in
- if no matching user exists, do not auto-provision silently
- instead show a controlled access-denied / not-linked message

### 3. Authorization

Keep existing app authorization rules.

Do not replace the current app role model:

- `admin`
- `member`
- chairperson-derived management access

SSO should authenticate identity only.
App roles and permissions should still come from the local database.

### 4. Session Model

After SSO success, `bookclub` should create and manage its own Rails session.

Do not depend on:

- `oqc` JWT tokens
- browser localStorage tokens from another app
- shared frontend auth state between apps

### 5. Logout

Define expected logout behavior explicitly.

Minimum acceptable behavior:

- logging out of `bookclub` clears the local Rails session

Optional enhancement:

- full Entra logout redirect if desired

## Suggested Implementation Shape

Recommended Rails approach:

- OIDC client integration in Rails
- callback endpoint handled by `bookclub`
- validate issuer, audience, nonce, and signature correctly
- extract email claim
- locate matching local `User`
- set `session[:user_id]`

Likely additions:

- SSO controller or auth callback controller
- routes for `/auth/microsoft` and callback
- environment variables for Entra tenant/client configuration
- sign-in page update
- tests for callback success/failure paths

## Environment / Config Expected

Likely required env vars:

- `ENTRA_TENANT_ID`
- `ENTRA_CLIENT_ID`
- `ENTRA_CLIENT_SECRET`
- `ENTRA_REDIRECT_URI`
- optional issuer / metadata URL settings if not derived automatically

Please choose naming consistent with the existing project style.

## Acceptance Criteria

The work is complete when all of the following are true:

1. `bookclub` provides a Microsoft SSO login entry point
2. User can authenticate against Entra ID and return to `bookclub`
3. Existing local `User` is resolved by email claim
4. Rails session is created locally in `bookclub`
5. Unknown/unlinked users are rejected safely
6. Existing authorization behavior remains unchanged after login
7. Local email/password login is either:
   - preserved as an explicit fallback for admins, or
   - intentionally disabled with a clear migration note
8. Automated tests cover:
   - successful SSO callback
   - unknown user / unlinked user
   - invalid callback / state / token failure

## Non-Goals

Do not:

- reuse `oqc` frontend login tokens
- implement brittle cross-app cookie sharing
- create a dependency where `bookclub` must call `oqc` to validate login

## Nice To Have

- feature flag to enable SSO in stages
- preserve local login for bootstrap/admin fallback
- login screen message explaining corporate sign-in
- audit log note for SSO-based sign-in

## Delivery Notes

If protocol choice is open, choose `OIDC` first and document why.

If there is any blocker around Entra app registration, required redirect URIs, or tenant restrictions, document those explicitly so infra/admin can complete setup quickly.
