-- ============================================================================
-- rls-multitenant.sql
-- Tenant isolation enforced by the database. Layer 3 (data store) of
-- references/layer-playbooks.md, and Default 1 and Default 3 of
-- references/app-defaults.md.
--
-- Target: PostgreSQL 13 or newer (gen_random_uuid() is built in from 13).
-- Run once, as the role that will own the schema. That role must not be a
-- superuser and must not have BYPASSRLS, because both ignore every policy
-- below.
--
-- One privilege is required beyond ownership: section 1 creates two roles, and
-- CREATE ROLE takes CREATEROLE or superuser. Either grant CREATEROLE to the
-- owning role for this run, or create app_client and app_anon separately as a
-- superuser and run the rest as the owner. The block in section 1 skips roles
-- that already exist, so the second path needs no other change to this file.
--
-- Placeholders to change: the schema name "app", the role names "app_client"
-- and "app_anon", the identity source inside app.current_user_id(), and the
-- table and column names. The mechanism is everything else.
--
-- Out of scope here, still required by layer 3: encryption at rest, backups
-- with a tested restore, and least-privilege roles per component.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Roles
--
-- app_client: the role the application connects as, or the role an
--   auto-generated REST layer switches to for an authenticated request. It owns
--   nothing, creates nothing, and bypasses nothing.
-- app_anon: unauthenticated callers. It exists so that every grant to it is
--   explicit and reviewable. It receives nothing in this file.
--
-- Server-side work that legitimately crosses tenants (tenant creation, billing
-- jobs, support tooling) needs a third role that bypasses policies. Create it
-- as a superuser, keep it off any connection that serves user requests:
--   CREATE ROLE app_service NOLOGIN BYPASSRLS;
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'app_client') THEN
    CREATE ROLE app_client NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'app_anon') THEN
    CREATE ROLE app_anon NOLOGIN;
  END IF;
END
$$;

CREATE SCHEMA IF NOT EXISTS app;

-- PUBLIC gets USAGE on schemas by default in some setups. Take it back, then
-- grant deliberately.
REVOKE ALL ON SCHEMA app FROM PUBLIC;
GRANT USAGE ON SCHEMA app TO app_client;

-- ----------------------------------------------------------------------------
-- 2. Identity source
--
-- Every policy below resolves the caller through this one function, so there is
-- exactly one place to change when the identity source changes.
--
-- The value is read from a runtime parameter the server sets. Two rules:
--
--   a) Set it with SET LOCAL, or set_config(..., true), inside the transaction
--      that does the work. A session-level value survives the request and is
--      handed to the next tenant by a connection pooler running in transaction
--      mode.
--   b) This pattern assumes the caller cannot execute arbitrary SQL. If a
--      browser talks to the database directly, it can set the parameter to any
--      value it likes, so the identity must come from a signature-verified
--      token instead. With PostgREST or Supabase, replace the body with:
--        SELECT nullif(
--          (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'),
--          '')::uuid
--      or simply: SELECT auth.uid()
--
-- Unset means NULL, NULL matches no membership row, and the answer is deny.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.current_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT nullif(current_setting('app.user_id', true), '')::uuid;
$$;

-- ----------------------------------------------------------------------------
-- 3. Tables
-- ----------------------------------------------------------------------------

CREATE TABLE app.tenants (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  -- Privileged column. Billing reads it, so a client that can write it can
  -- upgrade its own plan. Section 7 grants UPDATE column by column and leaves
  -- this one out of the grant.
  plan        text NOT NULL DEFAULT 'free'
              CONSTRAINT tenants_plan_allowed CHECK (plan IN ('free', 'pro', 'enterprise')),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.memberships (
  tenant_id   uuid NOT NULL REFERENCES app.tenants (id) ON DELETE CASCADE,
  -- Whatever your identity provider issues. Add a foreign key to your own users
  -- table if the identities live in this database.
  user_id     uuid NOT NULL,
  -- Privileged column, same reason as tenants.plan.
  role        text NOT NULL DEFAULT 'member'
              CONSTRAINT memberships_role_allowed CHECK (role IN ('member', 'admin')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, user_id)
);

CREATE INDEX memberships_user_idx ON app.memberships (user_id);

-- First tenant-scoped table.
CREATE TABLE app.customers (
  id          uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES app.tenants (id) ON DELETE CASCADE,
  name        text NOT NULL,
  email       text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id),
  -- Target of the composite foreign key on app.invoices. On its own this
  -- constraint adds nothing, because id is already unique. It exists so that
  -- (tenant_id, id) is a key another table is allowed to reference.
  CONSTRAINT customers_tenant_id_key UNIQUE (tenant_id, id)
);

CREATE INDEX customers_tenant_idx ON app.customers (tenant_id);

-- Second tenant-scoped table, and a child of the first.
CREATE TABLE app.invoices (
  id            uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL,
  customer_id   uuid NOT NULL,
  description   text NOT NULL DEFAULT '',
  -- Money is decided by the server (layer 13). Section 7 grants INSERT on the
  -- other columns only, so this one keeps its default unless privileged code
  -- writes it.
  amount_cents  integer NOT NULL DEFAULT 0 CHECK (amount_cents >= 0),
  status        text NOT NULL DEFAULT 'draft'
                CONSTRAINT invoices_status_allowed CHECK (status IN ('draft', 'sent', 'paid')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id),
  CONSTRAINT invoices_tenant_fkey
    FOREIGN KEY (tenant_id) REFERENCES app.tenants (id) ON DELETE CASCADE,

  -- ==========================================================================
  -- THE COMPOSITE FOREIGN KEY. Read this one before changing anything.
  --
  -- The obvious version of this column is:
  --     customer_id uuid NOT NULL REFERENCES app.customers (id)
  -- and it accepts any customer id in the whole database, including customers
  -- belonging to other tenants.
  --
  -- Row level security does not catch that. The policy on app.invoices checks
  -- the invoice's own tenant_id, and the invoice genuinely does belong to your
  -- tenant, so the write is allowed. The row that leaks is the one on the far
  -- end of the reference, and it leaks later: through a join in a report, an
  -- export, a PDF renderer, a support screen, or any code path that runs as a
  -- privileged role and trusts the reference because the parent row passed its
  -- ownership check.
  --
  -- Naming the tenant in the reference itself closes it. The pair
  -- (tenant_id, customer_id) must match an existing (tenant_id, id) pair in
  -- app.customers, so an invoice in tenant A physically cannot point at a
  -- customer in tenant B. The database refuses the write with a foreign key
  -- violation, before any application code is involved, and it refuses it for
  -- privileged roles too, which is where RLS stops helping.
  --
  -- What it costs: one redundant UNIQUE (tenant_id, id) on the parent, and
  -- tenant_id carried on the child. Both are cheap, and the denormalized
  -- tenant_id is the column the policy needs anyway.
  --
  -- Also note that tenant_id now appears in the policy and in the reference at
  -- the same time, so a row cannot be moved between tenants without breaking
  -- one of them. Section 7 leaves tenant_id out of the UPDATE grant to close
  -- the rest.
  --
  -- Apply this to EVERY foreign key that crosses a tenant boundary, including
  -- the ones your own design introduced ten minutes ago.
  -- ==========================================================================
  CONSTRAINT invoices_customer_same_tenant_fkey
    FOREIGN KEY (tenant_id, customer_id)
    REFERENCES app.customers (tenant_id, id)
    -- CASCADE keeps a tenant deletion working in a single statement. Use
    -- RESTRICT if invoices must outlive their customer, and then delete
    -- customers explicitly before the tenant.
    ON DELETE CASCADE
);

CREATE INDEX invoices_tenant_idx ON app.invoices (tenant_id);
CREATE INDEX invoices_customer_idx ON app.invoices (tenant_id, customer_id);

-- ----------------------------------------------------------------------------
-- 4. Row level security, enabled and forced
--
-- ENABLE applies policies to every role except the table owner. FORCE applies
-- them to the owner as well. The owner is usually the migration role, and on a
-- small deployment it is often the role the application connects as, which is
-- how a table with ENABLE alone ends up enforcing nothing.
--
-- Do this in the same migration that creates the table. A table that spends one
-- deploy without policies has been readable for that whole deploy.
-- ----------------------------------------------------------------------------
ALTER TABLE app.tenants      ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.tenants      FORCE  ROW LEVEL SECURITY;
ALTER TABLE app.memberships  ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.memberships  FORCE  ROW LEVEL SECURITY;
ALTER TABLE app.customers    ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.customers    FORCE  ROW LEVEL SECURITY;
ALTER TABLE app.invoices     ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.invoices     FORCE  ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 5. Membership helpers
--
-- SECURITY DEFINER, so the policies on other tables can ask "is the caller a
-- member of this tenant" without the caller holding any privilege on
-- app.memberships. Revoking SELECT on that table later changes nothing here.
--
-- SET search_path = '' pins resolution: nothing outside pg_catalog resolves
-- unqualified, so every object below is schema-qualified. pg_catalog is always
-- searched implicitly, which is why current_setting and nullif still resolve.
-- The empty path is what layer-playbooks.md prescribes in layer 3, and it is
-- the whole rule rather than a strict reading of it: leaving public in the path
-- reopens the resolution the pin exists to close, because any role holding
-- CREATE there can plant an object that matches. Without the pin, a caller who
-- controls schema resolution points the function at a table they own, and a
-- SECURITY DEFINER function is a privilege escalation path.
--
-- The function takes a tenant id and re-derives the caller itself. It never
-- accepts a user id from the caller, because a caller-supplied identity is the
-- thing being verified.
--
-- Owner: whichever role runs this file. Do not run this file as a superuser and
-- do not reassign these functions to one later, because the definer's privilege
-- is the owner's privilege.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.is_member(p_tenant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p_tenant_id IS NOT NULL
     AND EXISTS (
           SELECT 1
           FROM app.memberships AS m
           WHERE m.tenant_id = p_tenant_id
             AND m.user_id = app.current_user_id()
         );
$$;

CREATE OR REPLACE FUNCTION app.is_admin(p_tenant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p_tenant_id IS NOT NULL
     AND EXISTS (
           SELECT 1
           FROM app.memberships AS m
           WHERE m.tenant_id = p_tenant_id
             AND m.user_id = app.current_user_id()
             AND m.role = 'admin'
         );
$$;

-- Functions are executable by PUBLIC on creation. An auto-generated REST or RPC
-- layer publishes them to the internet, so treat EXECUTE the way you treat a
-- route: revoked by default, granted one function at a time.
REVOKE EXECUTE ON FUNCTION app.current_user_id(), app.is_member(uuid), app.is_admin(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION app.current_user_id(), app.is_member(uuid), app.is_admin(uuid) TO app_client;

-- ----------------------------------------------------------------------------
-- 6. Policies
--
-- Two halves, and they do different jobs:
--   USING      filters rows that already exist. It decides what SELECT returns
--              and which rows UPDATE and DELETE are allowed to touch.
--   WITH CHECK validates the row as it will exist after the write.
--
-- INSERT has no USING half, so WITH CHECK is the entire control there.
-- DELETE has no WITH CHECK half.
-- UPDATE needs both. With USING alone, a caller can take a row they legitimately
-- see and update it into a tenant they do not belong to: the row leaves, and
-- nothing complains.
--
-- One policy per command instead of FOR ALL, so both halves of each command are
-- visible in review and widening SELECT cannot silently widen DELETE.
--
-- Permissive policies OR together. Adding one always widens access. Use
-- AS RESTRICTIVE when the new condition must also hold.
-- ----------------------------------------------------------------------------

-- tenants: members read, admins rename. No INSERT or DELETE policy, so those
-- commands are denied for every non-bypassing role. That denial is the
-- deny-by-default half of the control, and it is why enabling RLS matters even
-- on tables with no policy at all.
CREATE POLICY tenants_select ON app.tenants
  FOR SELECT TO app_client
  USING (app.is_member(id));

CREATE POLICY tenants_update ON app.tenants
  FOR UPDATE TO app_client
  USING (app.is_admin(id))
  WITH CHECK (app.is_admin(id));

-- memberships: a caller sees their own rows and nothing else.
--
-- This policy deliberately has no TO clause, so it applies to every role,
-- including the owner that app.is_member() runs as. Naming app_client here
-- would make the helper return zero rows for everyone: FORCE ROW LEVEL SECURITY
-- subjects the owner to policies, and a policy addressed to app_client does not
-- cover the owner.
--
-- The predicate is also self-contained on purpose. A policy on app.memberships
-- that called app.is_member() would need to read app.memberships to decide
-- whether it may read app.memberships, and Postgres stops it with
-- "infinite recursion detected in policy for relation memberships".
--
-- If the product must list co-members, add a SECURITY DEFINER function that
-- returns the member list for a tenant the caller belongs to, and leave this
-- policy alone.
CREATE POLICY memberships_select_own ON app.memberships
  FOR SELECT
  USING (user_id = app.current_user_id());

-- No INSERT, UPDATE, or DELETE policy on memberships. Changing who belongs to a
-- tenant, and with which role, runs through server-side code that re-checks the
-- caller is an admin of that tenant.

-- customers
CREATE POLICY customers_select ON app.customers
  FOR SELECT TO app_client
  USING (app.is_member(tenant_id));

CREATE POLICY customers_insert ON app.customers
  FOR INSERT TO app_client
  WITH CHECK (app.is_member(tenant_id));

CREATE POLICY customers_update ON app.customers
  FOR UPDATE TO app_client
  USING (app.is_member(tenant_id))
  WITH CHECK (app.is_member(tenant_id));

CREATE POLICY customers_delete ON app.customers
  FOR DELETE TO app_client
  USING (app.is_member(tenant_id));

-- invoices
CREATE POLICY invoices_select ON app.invoices
  FOR SELECT TO app_client
  USING (app.is_member(tenant_id));

CREATE POLICY invoices_insert ON app.invoices
  FOR INSERT TO app_client
  WITH CHECK (app.is_member(tenant_id));

CREATE POLICY invoices_update ON app.invoices
  FOR UPDATE TO app_client
  USING (app.is_member(tenant_id))
  WITH CHECK (app.is_member(tenant_id));

CREATE POLICY invoices_delete ON app.invoices
  FOR DELETE TO app_client
  USING (app.is_member(tenant_id));

-- ----------------------------------------------------------------------------
-- 7. Table and column privileges
--
-- Policies decide which rows. Grants decide which columns. A policy cannot stop
-- a member from writing a column they hold UPDATE on, so the privileged columns
-- are left out of the grant instead of guarded by a rule somewhere upstream.
--
-- Column-level UPDATE is written as GRANT UPDATE (col, col) with no table-level
-- UPDATE anywhere. A single table-level GRANT UPDATE covers every column and
-- silently defeats this whole section.
-- ----------------------------------------------------------------------------

-- tenants: read the tenants you belong to, rename them if you are an admin.
-- "plan" is absent from the grant, so a client UPDATE that touches it is denied
-- by the privilege system before any policy runs.
GRANT SELECT           ON app.tenants TO app_client;
GRANT UPDATE (name)    ON app.tenants TO app_client;

-- memberships: read only. No write privilege of any kind, which is the
-- table-level form of the same control that GRANT UPDATE (col) applies at
-- column level. "role" is therefore unreachable from a client connection.
GRANT SELECT ON app.memberships TO app_client;

-- customers: full lifecycle inside the tenant. tenant_id is excluded from
-- UPDATE, so an existing row cannot be moved to another tenant even by a caller
-- who belongs to both.
-- INSERT is granted per column, not on the whole table. A table-level INSERT
-- lets the caller supply "id" itself, which defeats the generated default and
-- hands the client control of the primary key: it can collide rows on purpose,
-- or pick an identifier another part of the system is about to use. List the
-- columns the client is allowed to provide and let the rest take their defaults.
GRANT SELECT, DELETE            ON app.customers TO app_client;
GRANT INSERT (tenant_id, name, email) ON app.customers TO app_client;
GRANT UPDATE (name, email)      ON app.customers TO app_client;

-- invoices: the client may create and describe an invoice. It may not set the
-- amount or the status, because column-level INSERT covers only the listed
-- columns and the rest take their defaults. Server-side code with a higher
-- privilege sets the money.
GRANT SELECT, DELETE                              ON app.invoices TO app_client;
GRANT INSERT (tenant_id, customer_id, description) ON app.invoices TO app_client;
GRANT UPDATE (description, customer_id)            ON app.invoices TO app_client;

-- app_anon receives nothing. If a REST layer publishes this schema, the
-- anonymous role can reach exactly what is granted here, which is nothing.
-- Grants to it, if you ever add any, belong in this file next to this comment.

COMMIT;

-- ============================================================================
-- CROSS-TENANT DENIAL TESTS
--
-- Uncomment and run. The seed runs as a role that bypasses policies (app_service
-- or a superuser), because FORCE ROW LEVEL SECURITY covers the table owner too,
-- which is the entire point of FORCE.
--
-- Everything from "SET ROLE app_client" onward must run as app_client. Run these
-- as a superuser or a BYPASSRLS role and they all pass while proving nothing.
-- SET ROLE requires the current login role to be a member of app_client:
--   GRANT app_client TO <your_login_role>;
--
-- Run the statements one at a time, in autocommit. Inside a single explicit
-- transaction, the first expected error aborts every statement after it.
--
-- The same checks as a real test file: assets/tenancy.test.example.ts
-- ============================================================================

-- -- Seed, as app_service or superuser -------------------------------------
-- INSERT INTO app.tenants (id, name, plan) VALUES
--   ('11111111-1111-1111-1111-111111111111', 'Tenant A', 'free'),
--   ('22222222-2222-2222-2222-222222222222', 'Tenant B', 'free');
--
-- INSERT INTO app.memberships (tenant_id, user_id, role) VALUES
--   ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin'),
--   ('22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'admin');
--
-- INSERT INTO app.customers (id, tenant_id, name) VALUES
--   ('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'Customer of A'),
--   ('dddddddd-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', 'Customer of B');
--
-- -- Become the unprivileged client, acting as user A of tenant A -----------
-- SET ROLE app_client;
-- SELECT set_config('app.user_id', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
--   -- Session scope, the false, only because these statements run one at a time
--   -- in autocommit: each is its own transaction, so a transaction-scoped value
--   -- would be gone by the next line. Application code uses
--   -- set_config(..., true), or SET LOCAL, per rule (a) in section 2.
--
-- -- 0. Guard: confirm the tests are running as the role they claim to.
-- SELECT current_user,
--        (SELECT rolsuper     FROM pg_catalog.pg_roles WHERE rolname = current_user) AS is_superuser,
--        (SELECT rolbypassrls FROM pg_catalog.pg_roles WHERE rolname = current_user) AS bypasses_rls;
--   -- expect: app_client, false, false. Anything else invalidates every result below.
--
-- -- 1. Cross-tenant read denied.
-- SELECT count(*) FROM app.customers;
--   -- expect: 1 (tenant A only, out of two rows in the table)
-- SELECT count(*) FROM app.customers WHERE tenant_id = '22222222-2222-2222-2222-222222222222';
--   -- expect: 0
--
-- -- 2. Cross-tenant write denied.
-- INSERT INTO app.customers (tenant_id, name)
--   VALUES ('22222222-2222-2222-2222-222222222222', 'planted');
--   -- expect: ERROR, new row violates row-level security policy for table "customers"
--
-- -- 3. Cross-tenant update and delete touch nothing, and do not error.
-- UPDATE app.customers SET name = 'taken' WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
--   -- expect: UPDATE 0
-- DELETE FROM app.customers WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
--   -- expect: DELETE 0
--
-- -- 4. Privileged columns are unreachable from a client connection.
-- UPDATE app.tenants SET plan = 'enterprise' WHERE id = '11111111-1111-1111-1111-111111111111';
--   -- expect: ERROR, permission denied (no UPDATE privilege on column "plan")
-- UPDATE app.tenants SET name = 'Renamed'    WHERE id = '11111111-1111-1111-1111-111111111111';
--   -- expect: UPDATE 1 (user A is an admin of tenant A, and "name" is granted)
-- UPDATE app.memberships SET role = 'admin'
--   WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
--   -- expect: ERROR, permission denied (no UPDATE privilege on app.memberships at all)
-- INSERT INTO app.invoices (tenant_id, customer_id, description, amount_cents)
--   VALUES ('11111111-1111-1111-1111-111111111111',
--           'cccccccc-cccc-cccc-cccc-cccccccccccc', 'self-priced', 1);
--   -- expect: ERROR, permission denied (no INSERT privilege on column "amount_cents")
--
-- -- 5. Cross-tenant foreign key reference denied. This is the one RLS misses.
-- INSERT INTO app.invoices (tenant_id, customer_id, description)
--   VALUES ('11111111-1111-1111-1111-111111111111',
--           'dddddddd-dddd-dddd-dddd-dddddddddddd', 'points at another tenant');
--   -- expect: ERROR, insert or update on table "invoices" violates foreign key
--   --         constraint "invoices_customer_same_tenant_fkey"
--   -- The row policy accepts this row, because the invoice really is in tenant A.
--   -- The composite key is what refuses it.
--
-- -- 6. Not-found and not-yours are indistinguishable.
-- SELECT * FROM app.customers WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
--   -- expect: 0 rows (exists, other tenant)
-- SELECT * FROM app.customers WHERE id = '00000000-0000-0000-0000-000000000000';
--   -- expect: 0 rows (does not exist)
--   -- Identical here. The API layer has to preserve that: same status, same body,
--   -- same timing budget, or the difference becomes an enumeration oracle.
--
-- -- Cleanup ----------------------------------------------------------------
-- RESET ROLE;
-- DELETE FROM app.tenants WHERE id IN ('11111111-1111-1111-1111-111111111111',
--                                      '22222222-2222-2222-2222-222222222222');
--   -- cascades to memberships, customers, and invoices
