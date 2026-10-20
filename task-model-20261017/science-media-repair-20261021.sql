-- Derived artifact pointers may be removed when verified content corrects a video link.
-- No DELETE permission is added to business tables or status_history.
BEGIN;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='maizi_state_worker') THEN
   GRANT DELETE ON workflow.artifacts TO maizi_state_worker;
 END IF;
END $$;
COMMIT;
