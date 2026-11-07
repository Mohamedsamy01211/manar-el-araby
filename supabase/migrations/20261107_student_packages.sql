-- Manar El Araby: keep a separate history row for every student package.
create table if not exists public.student_packages (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  package_number integer not null check (package_number > 0),
  package_price numeric(12,2) not null default 0,
  total_lessons integer not null default 0 check (total_lessons >= 0),
  completed_lessons integer not null default 0 check (completed_lessons >= 0),
  paid_amount numeric(12,2) not null default 0,
  payment_status text not null default 'unpaid' check (payment_status in ('paid','unpaid','partial')),
  start_date date not null default current_date,
  is_current boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists student_packages_one_current_idx
  on public.student_packages(student_id) where is_current = true;
create unique index if not exists student_packages_number_idx
  on public.student_packages(student_id, package_number);
alter table public.student_packages enable row level security;
drop policy if exists "Users can view their own student packages" on public.student_packages;
create policy "Users can view their own student packages" on public.student_packages
  for select using (auth.uid() = user_id);
drop policy if exists "Users can insert their own student packages" on public.student_packages;
create policy "Users can insert their own student packages" on public.student_packages
  for insert with check (auth.uid() = user_id);
drop policy if exists "Users can update their own student packages" on public.student_packages;
create policy "Users can update their own student packages" on public.student_packages
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Users can delete their own student packages" on public.student_packages;
create policy "Users can delete their own student packages" on public.student_packages
  for delete using (auth.uid() = user_id);

-- Seed one current package per existing student without changing existing payment records.
insert into public.student_packages
  (student_id, user_id, package_number, package_price, total_lessons,
   completed_lessons, paid_amount, payment_status, start_date, is_current)
select
  s.id, s.user_id, 1, coalesce(s.package_price,0), coalesce(s.total_lessons,0),
  coalesce(s.completed_lessons,0), coalesce(s.paid,0),
  case
    when coalesce(s.paid,0) >= coalesce(s.package_price,0) and coalesce(s.package_price,0) > 0 then 'paid'
    when coalesce(s.paid,0) > 0 then 'partial'
    else 'unpaid'
  end,
  coalesce(s.package_start_date, s.created_at::date, current_date), true
from public.students s
where not exists (
  select 1 from public.student_packages p
  where p.student_id = s.id and p.is_current = true
);
