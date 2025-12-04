-- Enable pgvector extension
create extension if not exists vector;

-- PROFILES TABLE
create table public.profiles (
  id uuid references auth.users not null primary key,
  email text,
  full_name text,
  age int,
  gender text,
  location text,
  bio text,
  fcm_token text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.profiles enable row level security;

create policy "Users can view their own profile" on public.profiles
  for select using (auth.uid() = id);

create policy "Users can update their own profile" on public.profiles
  for update using (auth.uid() = id);

create policy "Users can insert their own profile" on public.profiles
  for insert with check (auth.uid() = id);

-- TIMELINES TABLE
create table public.timelines (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  title text not null,
  description text,
  symptoms jsonb not null default '[]'::jsonb,
  embedding vector(768), -- For Gemini embeddings
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.timelines enable row level security;

create policy "Users can view their own timelines" on public.timelines
  for select using (auth.uid() = user_id);

create policy "Users can insert their own timelines" on public.timelines
  for insert with check (auth.uid() = user_id);

create policy "Users can update their own timelines" on public.timelines
  for update using (auth.uid() = user_id);

create policy "Users can delete their own timelines" on public.timelines
  for delete using (auth.uid() = user_id);

-- NOTIFICATIONS TABLE
create table public.notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  title text not null,
  body text not null,
  data jsonb,
  read boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.notifications enable row level security;

create policy "Users can view their own notifications" on public.notifications
  for select using (auth.uid() = user_id);

-- MATCHING FUNCTION (RPC)
create or replace function match_timelines (
  query_embedding vector(768),
  match_threshold float,
  match_count int
)
returns table (
  id uuid,
  similarity float,
  diagnosis_label text,
  symptoms jsonb
)
language plpgsql
as $$
begin
  return query
  select
    timelines.id,
    1 - (timelines.embedding <=> query_embedding) as similarity,
    timelines.title as diagnosis_label, -- Using title as proxy for diagnosis label
    timelines.symptoms
  from timelines
  where 1 - (timelines.embedding <=> query_embedding) > match_threshold
  order by timelines.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- STORAGE BUCKET
-- Note: Buckets are usually created via API or Dashboard, but we can try SQL if enabled
insert into storage.buckets (id, name, public)
values ('reports', 'reports', true)
on conflict (id) do nothing;

create policy "Public Access to Reports"
  on storage.objects for select
  using ( bucket_id = 'reports' );

create policy "Users can upload reports"
  on storage.objects for insert
  with check ( bucket_id = 'reports' and auth.uid() = (storage.foldername(name))[1]::uuid );
