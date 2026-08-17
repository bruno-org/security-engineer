create table app.documents (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references app.tenants(id),
  title       text not null,
  body        text,
  created_at  timestamptz not null default now()
);

create index on app.documents (tenant_id);

alter table app.documents enable row level security;
alter table app.documents force row level security;

create policy documents_tenant_isolation on app.documents
  for all
  using      (tenant_id = app.current_tenant_id())
  with check (tenant_id = app.current_tenant_id());

-- INSERT is granted per column so the caller cannot supply "id" or bypass
-- the default, and UPDATE cannot move a row to another tenant.
grant select, delete                   on app.documents to app_client;
grant insert (tenant_id, title, body)  on app.documents to app_client;
grant update (title, body)             on app.documents to app_client;
