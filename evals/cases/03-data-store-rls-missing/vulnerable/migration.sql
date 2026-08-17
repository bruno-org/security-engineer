create table app.documents (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references app.tenants(id),
  title       text not null,
  body        text,
  created_at  timestamptz not null default now()
);

create index on app.documents (tenant_id);

grant select, insert, update, delete on app.documents to app_client;
