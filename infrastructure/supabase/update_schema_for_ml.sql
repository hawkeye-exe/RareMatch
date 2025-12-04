-- 7. Create REFERENCE_CASES table for ML Training Data
create table if not exists public.reference_cases (
  id uuid default gen_random_uuid() primary key,
  patient_id text, -- Original ID from CSV
  diagnosis_label text,
  symptoms jsonb, -- List of symptoms
  embedding vector(256),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS (read-only for public/authenticated)
alter table public.reference_cases enable row level security;

drop policy if exists "Public can view reference cases" on public.reference_cases;
create policy "Public can view reference cases" on public.reference_cases
  for select using (true);

-- 8. Create Matching Function for Reference Cases
create or replace function match_reference_cases (
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
    reference_cases.id,
    1 - (reference_cases.embedding <=> query_embedding) as similarity,
    reference_cases.diagnosis_label,
    reference_cases.symptoms
  from reference_cases
  where 1 - (reference_cases.embedding <=> query_embedding) > match_threshold
  order by reference_cases.embedding <=> query_embedding
  limit match_count;
end;
$$;
