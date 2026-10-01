-- Calendar: public holidays and observances, per region.
-- Read-only for signed-in users; filled by tool/refresh_holidays.mjs.
create table public.holidays (
  region text not null check (region in ('in', 'us', 'uk', 'ca', 'au', 'ae', 'sg', 'de', 'fr', 'jp')),
  date date not null,
  name text not null check (char_length(name) between 1 and 200),
  type text not null check (type in ('public', 'observance')),
  primary key (region, date, name)
);

create index holidays_region_date_idx on public.holidays (region, date);

alter table public.holidays enable row level security;

create policy "holidays: signed-in users can read"
  on public.holidays for select
  to authenticated
  using (true);

-- No insert/update/delete policies: only migrations change this table.
revoke insert, update, delete on public.holidays from anon, authenticated;
