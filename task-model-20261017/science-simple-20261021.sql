-- Non-destructive policy migration. Preserves all task rows and append-only history.
BEGIN;
ALTER TABLE business.tasks ALTER COLUMN status SET DEFAULT '文案待医生确认';
CREATE OR REPLACE FUNCTION business.create_task(
 p_title text, p_source text, p_actor uuid DEFAULT NULL, p_message text DEFAULT NULL,
 p_project uuid DEFAULT NULL, p_doctor uuid DEFAULT NULL, p_status text DEFAULT '文案待医生确认'
) RETURNS uuid LANGUAGE plpgsql SET search_path = business, pg_catalog AS $$
DECLARE tid uuid;
BEGIN
 INSERT INTO tasks(title,project_id,doctor_id,status,updated_by)
 VALUES(p_title,p_project,p_doctor,p_status,p_actor) RETURNING id INTO tid;
 INSERT INTO status_history(task_id,version,from_status,to_status,change_source,changed_by,source_message_uid)
 VALUES(tid,1,NULL,p_status,p_source,p_actor,p_message);
 RETURN tid;
END $$;
INSERT INTO workflow.meta(key,value) VALUES('workflowVersion','"science-simple-20261021-v1"')
ON CONFLICT(key) DO UPDATE SET value=excluded.value;

CREATE OR REPLACE FUNCTION business.science_simple_history_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path=business,pg_catalog AS $$
DECLARE kind text; active text;
BEGIN
 SELECT value::jsonb #>> '{}' INTO active FROM workflow.meta WHERE key='workflowVersion';
 IF active IS DISTINCT FROM 'science-simple-20261021-v1' OR NEW.change_source<>'自动识别' THEN RETURN NEW; END IF;
 SELECT content_type INTO kind FROM tasks WHERE id=NEW.task_id;
 -- Initial manuscript receipt can retain unknown type for manual resolution.
 IF NEW.version=1 THEN
   IF NEW.to_status<>'文案待医生确认' THEN RAISE EXCEPTION 'New automatic tasks start at manuscript confirmation' USING ERRCODE='23514'; END IF;
   RETURN NEW;
 END IF;
 IF kind IS DISTINCT FROM '科普' THEN RAISE EXCEPTION 'Simplified automatic progression is science-only' USING ERRCODE='23514'; END IF;
 IF NEW.from_status IN ('已发布','暂停','异常','已取消','已下架') THEN
   RAISE EXCEPTION 'Terminal/exception state requires manual action' USING ERRCODE='23514'; END IF;
 IF NOT (
   NEW.to_status='已发布' AND NEW.from_status IN ('文案待医生确认','文案修改中','待录制','待剪辑','剪辑中','成片待医生确认','成片修改中','待发布','已定时') OR
   NEW.to_status='文案待医生确认' AND NEW.from_status='文案修改中' OR
   NEW.to_status='文案修改中' AND NEW.from_status IN ('文案待医生确认','待录制') OR
   NEW.to_status='待录制' AND NEW.from_status IN ('文案待医生确认','文案修改中') OR
   NEW.to_status='待剪辑' AND NEW.from_status IN ('文案待医生确认','文案修改中','待录制') OR
   NEW.to_status='剪辑中' AND NEW.from_status='待剪辑' OR
   NEW.to_status='成片待医生确认' AND NEW.from_status IN ('文案待医生确认','文案修改中','待录制','待剪辑','剪辑中','成片修改中') OR
   NEW.to_status='成片修改中' AND NEW.from_status IN ('成片待医生确认','待发布') OR
   NEW.to_status='待发布' AND NEW.from_status IN ('成片待医生确认','成片修改中') OR
   NEW.to_status='已定时' AND NEW.from_status='待发布'
 ) THEN RAISE EXCEPTION 'Transition outside simplified science policy' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS science_simple_history_guard ON business.status_history;
CREATE TRIGGER science_simple_history_guard BEFORE INSERT ON business.status_history
FOR EACH ROW EXECUTE FUNCTION business.science_simple_history_guard();

CREATE OR REPLACE VIEW workflow.processing_summary AS
SELECT action,count(*) AS message_count,min(created_at) AS oldest_recorded_at
FROM workflow.decisions GROUP BY action;
-- Existing decisions/automation events retain source UIDs and concrete reasons.
COMMIT;
