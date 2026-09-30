-- Lokalni razvoj (supabase db reset): dva test naloga.
--   admin@whitetower.local / lozinka123  → admin u workspace-u White Tower
--   outsider@whitetower.local / lozinka123 → nije ni u jednom workspace-u
--                                             (ručna provera RLS-a: ne vidi ništa)
-- Workspace White Tower pravi migracija, ne ovaj fajl, jer mora postojati i u produkciji.

do $$
declare
  u record;
begin
  for u in
    select * from (values
      ('11111111-1111-4111-8111-111111111111'::uuid, 'admin@whitetower.local'),
      ('22222222-2222-4222-8222-222222222222'::uuid, 'outsider@whitetower.local')
    ) as t(id, email)
  loop
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated',
      u.email, extensions.crypt('lozinka123', extensions.gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', '{}', now(), now(),
      '', '', '', ''
    ) on conflict (id) do nothing;

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), u.id, u.id::text,
      jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
      'email', now(), now(), now()
    ) on conflict do nothing;
  end loop;
end
$$;

insert into public.workspace_members (workspace_id, user_id, role)
values ('00000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'admin')
on conflict (workspace_id, user_id) do nothing;
