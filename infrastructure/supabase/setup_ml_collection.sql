-- 1. Create the training_data table
create table if not exists public.training_data (
  id uuid default gen_random_uuid() primary key,
  original_timeline_id uuid, -- Link to original (optional). NO FK constraint to ensure data persists after timeline deletion.
  symptoms jsonb not null,
  diagnosis_label text, -- Can be filled later by experts or user confirmation
  age int,
  gender text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS (read-only for public/anon, write only via trigger/admin)
alter table public.training_data enable row level security;

-- 2. Create the Trigger Function
create or replace function public.archive_timeline_for_training()
returns trigger as $$
declare
  user_age int;
  user_gender text;
begin
  -- Try to fetch user demographics from profiles
  select age, gender into user_age, user_gender
  from public.profiles
  where id = new.user_id;

  -- Insert into training_data
  insert into public.training_data (
    original_timeline_id,
    symptoms,
    diagnosis_label, -- Initially null, to be labeled later
    age,
    gender
  ) values (
    new.id,
    new.symptoms,
    new.title, -- Using title as initial diagnosis guess/label
    user_age,
    user_gender
  );

  return new;
end;
$$ language plpgsql security definer;

-- 3. Attach the Trigger
drop trigger if exists on_timeline_created_for_ml on public.timelines;
create trigger on_timeline_created_for_ml
  after insert on public.timelines
  for each row execute procedure public.archive_timeline_for_training();
