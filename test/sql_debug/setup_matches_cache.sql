-- Create MATCHES table for caching ML results
create table if not exists public.matches (
  id uuid default gen_random_uuid() primary key,
  timeline_id uuid references public.timelines(id) on delete cascade not null,
  match_data jsonb not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.matches enable row level security;

-- Policies
drop policy if exists "Users can view their own matches" on public.matches;
create policy "Users can view their own matches" on public.matches
  for select using (
    exists (
      select 1 from public.timelines
      where timelines.id = matches.timeline_id
      and timelines.user_id = auth.uid()
    )
  );

drop policy if exists "Users can insert their own matches" on public.matches;
create policy "Users can insert their own matches" on public.matches
  for insert with check (
    exists (
      select 1 from public.timelines
      where timelines.id = matches.timeline_id
      and timelines.user_id = auth.uid()
    )
  );

drop policy if exists "Users can delete their own matches" on public.matches;
create policy "Users can delete their own matches" on public.matches
  for delete using (
    exists (
      select 1 from public.timelines
      where timelines.id = matches.timeline_id
      and timelines.user_id = auth.uid()
    )
  );

-- Index for faster lookups
create index if not exists matches_timeline_id_idx on public.matches(timeline_id);
