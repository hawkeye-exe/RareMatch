-- Enable pgvector extension
create extension if not exists vector;

-- 1. Create PROFILES table if it doesn't exist
create table if not exists public.profiles (
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

-- Enable RLS on profiles
alter table public.profiles enable row level security;

-- Create policies for profiles (drop existing to avoid conflicts)
drop policy if exists "Users can view their own profile" on public.profiles;
create policy "Users can view their own profile" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile" on public.profiles
  for update using (auth.uid() = id);

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile" on public.profiles
  for insert with check (auth.uid() = id);

-- 2. Create TIMELINES table
create table if not exists public.timelines (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  title text not null,
  description text,
  symptoms jsonb not null default '[]'::jsonb,
  embedding vector(256),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.timelines enable row level security;

drop policy if exists "Users can view their own timelines" on public.timelines;
create policy "Users can view their own timelines" on public.timelines
  for select using (auth.uid() = user_id);

drop policy if exists "Users can insert their own timelines" on public.timelines;
create policy "Users can insert their own timelines" on public.timelines
  for insert with check (auth.uid() = user_id);

drop policy if exists "Users can update their own timelines" on public.timelines;
create policy "Users can update their own timelines" on public.timelines
  for update using (auth.uid() = user_id);

drop policy if exists "Users can delete their own timelines" on public.timelines;
create policy "Users can delete their own timelines" on public.timelines
  for delete using (auth.uid() = user_id);

-- 3. Create Trigger Function with Safety Checks
create or replace function public.handle_new_user()
returns trigger as $$
declare
  age_val int;
begin
  -- Safely parse age
  begin
    age_val := (new.raw_user_meta_data->>'age')::int;
  exception when others then
    age_val := null;
  end;

  insert into public.profiles (id, email, full_name, age, gender)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    age_val,
    new.raw_user_meta_data->>'gender'
  );
  return new;
end;
$$ language plpgsql security definer;

-- 4. Attach Trigger
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 5. Create Matching Function
create or replace function match_timelines (
  query_embedding vector(256),
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
    timelines.title as diagnosis_label,
    timelines.symptoms
  from timelines
  where 1 - (timelines.embedding <=> query_embedding) > match_threshold
  order by timelines.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- 6. Enable Realtime for Timelines
-- This is crucial for the Flutter .stream() method to work
begin;
  drop publication if exists supabase_realtime;
  create publication supabase_realtime;
commit;
alter publication supabase_realtime add table timelines;
