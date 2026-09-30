-- Jedini workspace u fazi 1. Fiksni ID da bi ga skripte (dodavanje članova,
-- uvoz iz SE Rankinga, worker) mogle referencirati bez pretrage po nazivu.
insert into public.workspaces (id, name)
values ('00000000-0000-4000-8000-000000000001', 'White Tower')
on conflict (id) do nothing;
