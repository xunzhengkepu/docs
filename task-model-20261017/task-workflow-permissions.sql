-- Run as database owner in the intended task database after installing schemas.
BEGIN;
DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='maizi_state_worker') THEN
   CREATE ROLE maizi_state_worker LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
 END IF;
END $$;
GRANT USAGE ON SCHEMA business,workflow TO maizi_state_worker;
GRANT SELECT ON ALL TABLES IN SCHEMA business,workflow TO maizi_state_worker;
GRANT INSERT ON business.people,business.doctors,business.tasks,business.status_history TO maizi_state_worker;
GRANT UPDATE(status,status_version,updated_at,updated_by,doctor_id,content_type) ON business.tasks TO maizi_state_worker;
GRANT INSERT ON business.videos TO maizi_state_worker;
GRANT UPDATE(task_id,storage_path,download_status,sha256,kind,size_bytes,duration_ms) ON business.videos TO maizi_state_worker;
GRANT INSERT ON business.files TO maizi_state_worker;
GRANT UPDATE(task_id,kind,storage_path,download_status,sha256) ON business.files TO maizi_state_worker;
GRANT INSERT,UPDATE ON ALL TABLES IN SCHEMA workflow TO maizi_state_worker;
GRANT DELETE ON workflow.artifacts TO maizi_state_worker;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA workflow TO maizi_state_worker;

-- Existing DBeaver account can inspect both business data and sync decisions.
GRANT USAGE ON SCHEMA business,workflow TO xiaoxifenliu_app;
GRANT SELECT ON ALL TABLES IN SCHEMA business,workflow TO xiaoxifenliu_app;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA workflow GRANT SELECT ON TABLES TO xiaoxifenliu_app;
COMMIT;
