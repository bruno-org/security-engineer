/**
 * tenancy.test.example.ts
 *
 * The cross-tenant denial tests from references/verification.md, as a real test
 * file. Copy to tenancy.test.ts and change the PROJECT SETUP block.
 *
 * These run against the schema in assets/rls-multitenant.sql: a memberships
 * table, row level security enabled and forced, and a composite foreign key
 * that ties a child row to its parent's tenant.
 *
 * Two rules decide whether this file proves anything:
 *
 *   1. It talks to a real database through an unprivileged role. Mocking the
 *      access rules and asserting the mock says no proves that the mock says
 *      no. The rules are the thing under test.
 *   2. The connection must not be a superuser and must not hold BYPASSRLS.
 *      Both ignore every policy, so every test below would pass on a database
 *      with no policies at all. Test 0 exists to catch exactly that.
 *
 * Written for Vitest. Jest uses the same names, so deleting the import line is
 * usually the whole migration.
 *
 *   npm i -D vitest pg @types/pg
 *   TEST_DATABASE_URL=... TEST_ADMIN_DATABASE_URL=... npx vitest run
 *
 * pg ships no types of its own, so @types/pg is what makes the QueryResult
 * import below resolve.
 */

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Pool, type QueryResult } from 'pg';

// ---------------------------------------------------------------------------
// PROJECT SETUP. This block is the part you change.
//
// TEST_DATABASE_URL       a login role that is a member of app_client, and is
//                         neither a superuser nor BYPASSRLS
// TEST_ADMIN_DATABASE_URL the role that seeds fixtures across tenants, meaning
//                         app_service or a superuser
//
// Point both at a disposable database. Nothing here should ever run against
// production data.
// ---------------------------------------------------------------------------

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set. Point it at a disposable test database.`);
  return value;
}

const clientPool = new Pool({ connectionString: required('TEST_DATABASE_URL') });
const adminPool = new Pool({ connectionString: required('TEST_ADMIN_DATABASE_URL') });

const TENANT_A = '11111111-1111-1111-1111-111111111111';
const TENANT_B = '22222222-2222-2222-2222-222222222222';
const USER_A = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const USER_B = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const CUSTOMER_A = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
const CUSTOMER_B = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
const NO_SUCH_ID = '00000000-0000-0000-0000-000000000000';

type Query = (text: string, params?: unknown[]) => Promise<QueryResult>;

/**
 * Runs a block as the unprivileged application role, acting as one user.
 *
 * SET LOCAL and set_config(..., true) are transaction-scoped on purpose: a
 * session-level value survives the request and gets handed to the next tenant
 * by a pooler running in transaction mode. The rollback at the end means no
 * test can leave a row behind, including the ones that are supposed to fail.
 *
 * Supabase or PostgREST equivalent: build a client with the anon key and a real
 * signed user token, and drop the SET LOCAL lines. The identity then comes from
 * the verified token, which is what a browser-facing deployment requires.
 */
async function asUser<T>(userId: string, run: (query: Query) => Promise<T>): Promise<T> {
  const connection = await clientPool.connect();
  try {
    await connection.query('BEGIN');
    await connection.query('SET LOCAL ROLE app_client');
    await connection.query('SELECT set_config($1, $2, true)', ['app.user_id', userId]);
    return await run((text, params) => connection.query(text, params));
  } finally {
    await connection.query('ROLLBACK').catch(() => undefined);
    connection.release();
  }
}

/** PostgreSQL error codes worth asserting by number rather than by message. */
const INSUFFICIENT_PRIVILEGE = '42501'; // row policy violated, or column privilege missing
const FOREIGN_KEY_VIOLATION = '23503'; // the composite key refused the reference

// 42501 is raised by three different denials: a policy refusing the row
// ("new row violates row-level security policy"), a missing table or column
// privilege ("permission denied for table X"), and "permission denied to set
// role", which the SET LOCAL ROLE in asUser() raises before the statement under
// test is ever sent. The code alone cannot tell them apart, so every denial
// below pins the message too and names which of the three it expects.

// ---------------------------------------------------------------------------
// Fixtures. Seeded with the admin role because the tenant-crossing insert is
// exactly what the policies are there to prevent.
// ---------------------------------------------------------------------------

beforeAll(async () => {
  await adminPool.query(
    `INSERT INTO app.tenants (id, name, plan) VALUES ($1, 'Tenant A', 'free'), ($2, 'Tenant B', 'free')`,
    [TENANT_A, TENANT_B]
  );
  await adminPool.query(
    `INSERT INTO app.memberships (tenant_id, user_id, role) VALUES ($1, $2, 'admin'), ($3, $4, 'admin')`,
    [TENANT_A, USER_A, TENANT_B, USER_B]
  );
  await adminPool.query(
    `INSERT INTO app.customers (id, tenant_id, name) VALUES ($1, $2, 'Customer of A'), ($3, $4, 'Customer of B')`,
    [CUSTOMER_A, TENANT_A, CUSTOMER_B, TENANT_B]
  );
});

afterAll(async () => {
  // Cascades to memberships, customers, and invoices.
  await adminPool.query('DELETE FROM app.tenants WHERE id = ANY($1)', [[TENANT_A, TENANT_B]]);
  await adminPool.end();
  await clientPool.end();
});

describe('tenant isolation', () => {
  // -------------------------------------------------------------------------
  // 0. The guard. Without it, a connection string pointing at a superuser makes
  //    every test below pass while proving the opposite of what it claims.
  //
  //    It reads two roles, because they answer different questions. current_user
  //    is what asUser() switched to, so it only confirms the switch happened.
  //    session_user is the login role behind TEST_DATABASE_URL, which SET LOCAL
  //    ROLE does not change, and it is the one that fails when the connection
  //    string points at a superuser or at a BYPASSRLS role.
  // -------------------------------------------------------------------------
  it('runs as an unprivileged role that cannot bypass the rules', async () => {
    const result = await asUser(USER_A, (query) =>
      query(`SELECT session_user  AS login_role,
                    current_user  AS role,
                    (SELECT rolsuper     FROM pg_catalog.pg_roles WHERE rolname = session_user) AS login_is_superuser,
                    (SELECT rolbypassrls FROM pg_catalog.pg_roles WHERE rolname = session_user) AS login_bypasses_rls,
                    (SELECT rolsuper     FROM pg_catalog.pg_roles WHERE rolname = current_user) AS is_superuser,
                    (SELECT rolbypassrls FROM pg_catalog.pg_roles WHERE rolname = current_user) AS bypasses_rls`)
    );

    expect(result.rows[0].role).toBe('app_client');
    expect(result.rows[0].login_is_superuser).toBe(false);
    expect(result.rows[0].login_bypasses_rls).toBe(false);
    expect(result.rows[0].is_superuser).toBe(false);
    expect(result.rows[0].bypasses_rls).toBe(false);
  });

  // -------------------------------------------------------------------------
  // 1. Cross-tenant read denied.
  // -------------------------------------------------------------------------
  it('does not return another tenant rows on a read', async () => {
    const byId = await asUser(USER_A, (query) =>
      query('SELECT id FROM app.customers WHERE id = $1', [CUSTOMER_B])
    );
    expect(byId.rowCount).toBe(0);

    // Also check the unfiltered read, because that is the query a report or an
    // export runs, and it is where a missing policy shows up first.
    const all = await asUser(USER_A, (query) => query('SELECT tenant_id FROM app.customers'));
    // Assert the row count first. Array.prototype.every() returns true on an empty
    // array, so the ownership assertion alone would pass against a broken fixture
    // that returned nothing, which is the classic vacuously-passing security test.
    expect(all.rows.length).toBeGreaterThan(0);
    expect(all.rows.every((row) => row.tenant_id === TENANT_A)).toBe(true);
  });

  // -------------------------------------------------------------------------
  // 2. Cross-tenant write denied.
  // -------------------------------------------------------------------------
  it('refuses an insert into another tenant', async () => {
    // A write is the half of the boundary that raises. A read of the same rows
    // returns zero rows instead, which is why test 1 asserts a count and this
    // one asserts an error.
    await expect(
      asUser(USER_A, (query) =>
        query('INSERT INTO app.customers (tenant_id, name) VALUES ($1, $2)', [TENANT_B, 'planted'])
      )
    ).rejects.toMatchObject({
      code: INSUFFICIENT_PRIVILEGE,
      // The WITH CHECK half of customers_insert refused the row. A grant problem
      // would say "permission denied" instead, and would not prove the policy.
      message: expect.stringContaining('row-level security policy'),
    });
  });

  it('changes nothing when updating or deleting another tenant row', async () => {
    // These are not errors. The rows are invisible, so the statement matches
    // zero rows, which is the same answer the caller gets for an id that never
    // existed.
    const updated = await asUser(USER_A, (query) =>
      query('UPDATE app.customers SET name = $1 WHERE id = $2', ['taken', CUSTOMER_B])
    );
    expect(updated.rowCount).toBe(0);

    const deleted = await asUser(USER_A, (query) =>
      query('DELETE FROM app.customers WHERE id = $1', [CUSTOMER_B])
    );
    expect(deleted.rowCount).toBe(0);

    // And the row is still there, seen from its own tenant.
    const stillThere = await asUser(USER_B, (query) =>
      query('SELECT name FROM app.customers WHERE id = $1', [CUSTOMER_B])
    );
    expect(stillThere.rows[0].name).toBe('Customer of B');
  });

  // -------------------------------------------------------------------------
  // 3. Privileged column write denied. Being an admin of your own tenant is not
  //    permission to write the columns that decide billing and access.
  // -------------------------------------------------------------------------
  it('refuses a write to a privileged column', async () => {
    await expect(
      asUser(USER_A, (query) =>
        query('UPDATE app.tenants SET plan = $1 WHERE id = $2', ['enterprise', TENANT_A])
      )
    ).rejects.toMatchObject({
      code: INSUFFICIENT_PRIVILEGE,
      // "plan" is absent from GRANT UPDATE (name), so the privilege system
      // refuses the statement before any policy is consulted.
      message: expect.stringContaining('permission denied for table tenants'),
    });

    await expect(
      asUser(USER_A, (query) =>
        query('UPDATE app.memberships SET role = $1 WHERE user_id = $2', ['admin', USER_A])
      )
    ).rejects.toMatchObject({
      code: INSUFFICIENT_PRIVILEGE,
      message: expect.stringContaining('permission denied for table memberships'),
    });

    await expect(
      asUser(USER_A, (query) =>
        query(
          `INSERT INTO app.invoices (tenant_id, customer_id, description, amount_cents)
           VALUES ($1, $2, 'self-priced', 1)`,
          [TENANT_A, CUSTOMER_A]
        )
      )
    ).rejects.toMatchObject({
      code: INSUFFICIENT_PRIVILEGE,
      message: expect.stringContaining('permission denied for table invoices'),
    });

    // The non-privileged column on the same table still works, so the test
    // above is measuring the column grant rather than a broken connection.
    const renamed = await asUser(USER_A, (query) =>
      query('UPDATE app.tenants SET name = $1 WHERE id = $2', ['Renamed', TENANT_A])
    );
    expect(renamed.rowCount).toBe(1);

    // Nothing changed on the real row: asUser rolls back.
    const plan = await adminPool.query('SELECT plan, name FROM app.tenants WHERE id = $1', [TENANT_A]);
    expect(plan.rows[0].plan).toBe('free');
  });

  // -------------------------------------------------------------------------
  // 4. Cross-tenant foreign key reference denied.
  //    The row policy accepts this insert: the invoice really does belong to
  //    tenant A. The composite key is the only thing that refuses it, which is
  //    why this test exists separately from test 2.
  // -------------------------------------------------------------------------
  it('refuses an invoice in one tenant that references a customer in another', async () => {
    await expect(
      asUser(USER_A, (query) =>
        query(
          `INSERT INTO app.invoices (tenant_id, customer_id, description)
           VALUES ($1, $2, 'points at another tenant')`,
          [TENANT_A, CUSTOMER_B]
        )
      )
    ).rejects.toMatchObject({ code: FOREIGN_KEY_VIOLATION });

    // The same insert against a customer in the caller's own tenant succeeds,
    // so the constraint is refusing the tenant mismatch rather than everything.
    const ok = await asUser(USER_A, (query) =>
      query(
        `INSERT INTO app.invoices (tenant_id, customer_id, description)
         VALUES ($1, $2, 'own customer') RETURNING id`,
        [TENANT_A, CUSTOMER_A]
      )
    );
    expect(ok.rowCount).toBe(1);
  });

  // -------------------------------------------------------------------------
  // 5. Not-found and not-yours are indistinguishable.
  //    A different answer for the two is an enumeration oracle: the attacker
  //    stops guessing identifiers and starts reading the difference.
  // -------------------------------------------------------------------------
  it('answers identically for a record that is not yours and one that does not exist', async () => {
    const notYours = await asUser(USER_A, (query) =>
      query('SELECT * FROM app.customers WHERE id = $1', [CUSTOMER_B])
    );
    const notFound = await asUser(USER_A, (query) =>
      query('SELECT * FROM app.customers WHERE id = $1', [NO_SUCH_ID])
    );

    expect(notYours.rowCount).toBe(notFound.rowCount);
    expect(notYours.rows).toEqual(notFound.rows);
  });
});

/**
 * The same five checks at the HTTP layer, for projects where the unprivileged
 * client is the API rather than the database. Run them with two real logged-in
 * sessions, never with a forged token or a mocked session middleware:
 *
 *   GET    /api/customers/CUSTOMER_B  as user A  -> 404, byte-identical to
 *                                                  GET /api/customers/NO_SUCH_ID
 *   POST   /api/customers { tenantId: TENANT_B } as user A -> 403
 *   PATCH  /api/tenants/TENANT_A { plan: 'enterprise' }    -> 403, and the
 *                                                  stored plan is unchanged
 *   POST   /api/invoices { customerId: CUSTOMER_B }        -> 400 or 403
 *   DELETE /api/customers/CUSTOMER_B as user A   -> same status as deleting an
 *                                                  id that never existed
 *
 * Assert the status, the body, and that the record is still there afterwards.
 * A 200 with an empty list is a pass; a 200 with someone else's record is the
 * finding this whole file exists to catch.
 */
