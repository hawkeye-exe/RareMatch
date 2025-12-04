-- Create the 'reports' bucket if it doesn't exist
insert into storage.buckets (id, name, public)
values ('reports', 'reports', true)
on conflict (id) do nothing;

-- Set up security policies for the 'reports' bucket

-- 1. Allow authenticated users to upload files
create policy "Authenticated users can upload reports"
on storage.objects for insert
with check (
  bucket_id = 'reports' and
  auth.role() = 'authenticated'
);

-- 2. Allow public access to view reports (since we generate a public URL)
create policy "Public can view reports"
on storage.objects for select
using ( bucket_id = 'reports' );

-- 3. Allow users to delete their own reports (optional but good practice)
create policy "Users can delete their own reports"
on storage.objects for delete
using (
  bucket_id = 'reports' and
  auth.uid() = owner
);
