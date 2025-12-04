-- Safely enable Realtime for the timelines table
do $$
begin
  -- 1. Create publication if it doesn't exist
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;

  -- 2. Add table to publication if not already a member
  if not exists (
    select 1
    from pg_publication_rel pr
    join pg_publication p on p.oid = pr.prpubid
    join pg_class c on c.oid = pr.prrelid
    where p.pubname = 'supabase_realtime' and c.relname = 'timelines'
  ) then
    alter publication supabase_realtime add table timelines;
  end if;
end
$$;

-- 3. Set Replica Identity to FULL (ensures deletes are broadcast correctly)
alter table timelines replica identity full;

-- Verify it worked
select * from pg_publication_tables where pubname = 'supabase_realtime';
