-- RareMatch Consolidated SQL Schema
-- Includes: Profiles, Timelines, Notifications, Matches, Feedback, ML Data, Storage, Realtime

-- 1. EXTENSIONS
create extension if not exists vector;

-- 2. PROFILES
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
alter table public.profiles enable row level security;

create policy "Users can view their own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users can update their own profile" on public.profiles for update using (auth.uid() = id);
create policy "Users can insert their own profile" on public.profiles for insert with check (auth.uid() = id);

-- 3. TIMELINES
create table if not exists public.timelines (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  title text not null,
  description text,
  symptoms jsonb not null default '[]'::jsonb,
  embedding vector(768), -- Gemini Embedding
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.timelines enable row level security;

create policy "Users can view their own timelines" on public.timelines for select using (auth.uid() = user_id);
create policy "Users can insert their own timelines" on public.timelines for insert with check (auth.uid() = user_id);
create policy "Users can update their own timelines" on public.timelines for update using (auth.uid() = user_id);
create policy "Users can delete their own timelines" on public.timelines for delete using (auth.uid() = user_id);

-- 4. NOTIFICATIONS
create table if not exists public.notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  title text not null,
  body text not null,
  data jsonb,
  read boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.notifications enable row level security;

create policy "Users can view their own notifications" on public.notifications for select using (auth.uid() = user_id);

-- 5. MATCHES (Cache)
create table if not exists public.matches (
  id uuid default gen_random_uuid() primary key,
  timeline_id uuid references public.timelines(id) on delete cascade not null,
  match_data jsonb not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.matches enable row level security;

create policy "Users can view their own matches" on public.matches for select using (
  exists (select 1 from public.timelines where timelines.id = matches.timeline_id and timelines.user_id = auth.uid())
);
create policy "Users can insert their own matches" on public.matches for insert with check (
  exists (select 1 from public.timelines where timelines.id = matches.timeline_id and timelines.user_id = auth.uid())
);
create policy "Users can delete their own matches" on public.matches for delete using (
  exists (select 1 from public.timelines where timelines.id = matches.timeline_id and timelines.user_id = auth.uid())
);
create index if not exists matches_timeline_id_idx on public.matches(timeline_id);

-- 6. MATCH FEEDBACK
create table if not exists public.match_feedback (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade,
    timeline_id uuid references public.timelines(id) on delete cascade,
    match_id text not null,
    is_helpful boolean not null,
    created_at timestamp with time zone default now()
);
alter table public.match_feedback enable row level security;

create policy "Users can insert their own feedback" on public.match_feedback for insert with check (auth.uid() = user_id);
create policy "Users can view their own feedback" on public.match_feedback for select using (auth.uid() = user_id);

-- 7. ML TRAINING DATA (Collection)
create table if not exists public.training_data (
  id uuid default gen_random_uuid() primary key,
  original_timeline_id uuid,
  symptoms jsonb not null,
  diagnosis_label text,
  age int,
  gender text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.training_data enable row level security;

-- 8. REFERENCE CASES (For Matching)
create table if not exists public.reference_cases (
  id uuid default gen_random_uuid() primary key,
  patient_id text,
  diagnosis_label text,
  symptoms jsonb,
  embedding vector(768),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.reference_cases enable row level security;
create policy "Public can view reference cases" on public.reference_cases for select using (true);

-- 9. STORAGE BUCKETS
insert into storage.buckets (id, name, public) values ('reports', 'reports', true) on conflict (id) do nothing;

create policy "Authenticated users can upload reports" on storage.objects for insert with check (bucket_id = 'reports' and auth.role() = 'authenticated');
create policy "Public can view reports" on storage.objects for select using (bucket_id = 'reports');
create policy "Users can delete their own reports" on storage.objects for delete using (bucket_id = 'reports' and auth.uid() = owner);

-- 10. FUNCTIONS & TRIGGERS

-- Handle New User (Profile Creation)
create or replace function public.handle_new_user() returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, age, gender)
  values (
    new.id, new.email, new.raw_user_meta_data->>'full_name',
    (new.raw_user_meta_data->>'age')::int, new.raw_user_meta_data->>'gender'
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- Archive Timeline for Training
create or replace function public.archive_timeline_for_training() returns trigger as $$
declare
  user_age int;
  user_gender text;
begin
  select age, gender into user_age, user_gender from public.profiles where id = new.user_id;
  insert into public.training_data (original_timeline_id, symptoms, diagnosis_label, age, gender)
  values (new.id, new.symptoms, new.title, user_age, user_gender);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_timeline_created_for_ml on public.timelines;
create trigger on_timeline_created_for_ml after insert on public.timelines for each row execute procedure public.archive_timeline_for_training();

-- Match Timelines (Vector Search)
create or replace function match_timelines (
  query_embedding vector(768),
  match_threshold float,
  match_count int
) returns table (
  id uuid, similarity float, diagnosis_label text, symptoms jsonb
) language plpgsql as $$
begin
  return query
  select timelines.id, 1 - (timelines.embedding <=> query_embedding) as similarity, timelines.title as diagnosis_label, timelines.symptoms
  from timelines
  where 1 - (timelines.embedding <=> query_embedding) > match_threshold
  order by timelines.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- Match Reference Cases (Vector Search)
create or replace function match_reference_cases (
  query_embedding vector(768),
  match_threshold float,
  match_count int
) returns table (
  id uuid, similarity float, diagnosis_label text, symptoms jsonb
) language plpgsql as $$
begin
  return query
  select reference_cases.id, 1 - (reference_cases.embedding <=> query_embedding) as similarity, reference_cases.diagnosis_label, reference_cases.symptoms
  from reference_cases
  where 1 - (reference_cases.embedding <=> query_embedding) > match_threshold
  order by reference_cases.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- 11. REALTIME SETUP
begin;
  drop publication if exists supabase_realtime;
  create publication supabase_realtime;
commit;
alter publication supabase_realtime add table timelines;
alter table timelines replica identity full;
