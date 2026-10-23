-- AbMo Budget Tracker shared household schema for Supabase.
-- Run this whole file in Supabase Dashboard > SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Our Home Budget',
  invite_code text not null unique default encode(gen_random_bytes(24), 'hex'),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);
create table if not exists public.household_settings (
  household_id uuid primary key references public.households(id) on delete cascade,
  monthly_income numeric not null default 0,
  opening_savings numeric not null default 0,
  budgets jsonb not null default '{"Housing":2200,"Groceries":650,"Utilities":300,"Transport":300,"Lifestyle":400}'::jsonb,
  updated_at timestamptz not null default now()
);
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  category text not null default 'Other',
  amount numeric not null check (amount > 0),
  date date not null default current_date,
  kind text not null check (kind in ('income','expense')),
  visibility text not null default 'shared' check (visibility in ('shared','personal')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists transactions_household_date_idx on public.transactions(household_id, date desc);

create or replace function public.is_household_member(hid uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.household_members m where m.household_id = hid and m.user_id = auth.uid()) $$;

create or replace function public.create_household(household_name text default 'Our Home Budget')
returns table(household_id uuid, invite_code text)
language plpgsql security definer set search_path = public
as $$
declare h public.households%rowtype;
begin
  if auth.uid() is null then raise exception 'Please sign in first'; end if;
  if exists(select 1 from public.household_members where user_id = auth.uid()) then
    raise exception 'This account already belongs to a household';
  end if;
  insert into public.households(name, created_by) values (coalesce(nullif(trim(household_name),''),'Our Home Budget'), auth.uid()) returning * into h;
  insert into public.household_members(household_id,user_id,role) values(h.id,auth.uid(),'owner');
  insert into public.household_settings(household_id) values(h.id);
  return query select h.id, h.invite_code;
end $$;

create or replace function public.join_household(code text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare hid uuid;
begin
  if auth.uid() is null then raise exception 'Please sign in first'; end if;
  select id into hid from public.households where invite_code = code;
  if hid is null then raise exception 'That invitation link is invalid or expired'; end if;
  if exists(select 1 from public.household_members where user_id = auth.uid() and household_id <> hid) then
    raise exception 'This account already belongs to another household';
  end if;
  insert into public.household_members(household_id,user_id,role) values(hid,auth.uid(),'member') on conflict do nothing;
  return hid;
end $$;

create or replace function public.rotate_household_invite()
returns text language plpgsql security definer set search_path = public
as $$
declare hid uuid; new_code text;
begin
  select household_id into hid from public.household_members where user_id=auth.uid() and role='owner' limit 1;
  if hid is null then raise exception 'Only the household owner can create a new invite'; end if;
  new_code := encode(gen_random_bytes(24), 'hex');
  update public.households set invite_code=new_code where id=hid;
  return new_code;
end $$;

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_settings enable row level security;
alter table public.transactions enable row level security;

drop policy if exists household_read_members on public.households;
create policy household_read_members on public.households for select to authenticated using (public.is_household_member(id));
drop policy if exists member_read_members on public.household_members;
create policy member_read_members on public.household_members for select to authenticated using (public.is_household_member(household_id));
drop policy if exists settings_member_all on public.household_settings;
create policy settings_member_all on public.household_settings for all to authenticated using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
drop policy if exists tx_select_visible on public.transactions;
create policy tx_select_visible on public.transactions for select to authenticated using (public.is_household_member(household_id) and (visibility='shared' or owner_id=auth.uid()));
drop policy if exists tx_insert_member on public.transactions;
create policy tx_insert_member on public.transactions for insert to authenticated with check (public.is_household_member(household_id) and owner_id=auth.uid());
drop policy if exists tx_update_visible on public.transactions;
create policy tx_update_visible on public.transactions for update to authenticated using (public.is_household_member(household_id) and (visibility='shared' or owner_id=auth.uid())) with check (public.is_household_member(household_id) and (visibility='shared' or owner_id=auth.uid()));
drop policy if exists tx_delete_visible on public.transactions;
create policy tx_delete_visible on public.transactions for delete to authenticated using (public.is_household_member(household_id) and (visibility='shared' or owner_id=auth.uid()));

grant execute on function public.create_household(text) to authenticated;
grant execute on function public.join_household(text) to authenticated;
grant execute on function public.rotate_household_invite() to authenticated;
grant execute on function public.is_household_member(uuid) to authenticated;
grant select on public.households, public.household_members to authenticated;
grant select, insert, update, delete on public.transactions to authenticated;
grant select, insert, update, delete on public.household_settings to authenticated;
