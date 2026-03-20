-- Migration 038: Seed edge function URL and anon key into app_config
-- Values are taken from the project's own dart_defines.env.
UPDATE public.app_config
  SET value = 'https://mcmlawztwyrjcwmieciw.supabase.co/functions/v1'
  WHERE key = 'edge_function_url';

UPDATE public.app_config
  SET value = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4Nzc0NTgsImV4cCI6MjA4ODQ1MzQ1OH0.qFvDzJrHFUaJjucCxkJXvmtkRdumhm5wC0DxQu-Q-AE'
  WHERE key = 'edge_anon_key';
