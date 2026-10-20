-- Install operational tables alongside the existing 13 business tables.
-- Business state, history, checkpoints and delivery intent commit together.
BEGIN;
CREATE SCHEMA IF NOT EXISTS workflow;
CREATE TABLE IF NOT EXISTS workflow.meta(key text PRIMARY KEY,value text NOT NULL);
CREATE TABLE IF NOT EXISTS workflow.local_tasks(
 task_id uuid PRIMARY KEY REFERENCES business.tasks(id),source_uid text NOT NULL UNIQUE,
 chat_id text NOT NULL,doctor text NOT NULL);
CREATE TABLE IF NOT EXISTS workflow.document_observations(
 source_uid text PRIMARY KEY,file_id uuid NOT NULL UNIQUE REFERENCES business.files(id),
 message_id bigint NOT NULL UNIQUE,chat_id text NOT NULL,sent_at bigint NOT NULL,
 reason text NOT NULL,updated_at timestamptz NOT NULL);
CREATE INDEX IF NOT EXISTS files_source_message_uid_idx ON business.files(source_message_uid);
CREATE TABLE IF NOT EXISTS workflow.automation_events(
 event_key text PRIMARY KEY,source_uid text NOT NULL,message_id bigint NOT NULL,chat_id text NOT NULL,
 task_id uuid REFERENCES business.tasks(id),kind text NOT NULL,action text NOT NULL,reason text NOT NULL,
 detail text NOT NULL,updated_at timestamptz NOT NULL);
CREATE INDEX IF NOT EXISTS automation_source ON workflow.automation_events(source_uid);
CREATE OR REPLACE VIEW workflow.automation_attention AS
SELECT e.message_id,e.source_uid,e.chat_id,e.task_id,t.title,e.kind,e.action,e.reason,e.detail::jsonb AS evidence,e.updated_at
FROM workflow.automation_events e LEFT JOIN business.tasks t ON t.id=e.task_id
WHERE e.action IN ('needs_review','waiting','invalid_transition','manual_protected','conflict','error');
CREATE TABLE IF NOT EXISTS workflow.legacy_fields(
 entity_table text NOT NULL,entity_id uuid NOT NULL,fields jsonb NOT NULL,
 PRIMARY KEY(entity_table,entity_id));
CREATE TABLE IF NOT EXISTS workflow.bindings(
 task_id uuid PRIMARY KEY REFERENCES business.tasks(id),record_id text NOT NULL UNIQUE,
 business_id text NOT NULL,title text NOT NULL,doctor text NOT NULL,content_type text NOT NULL,
 snapshot text NOT NULL,enabled integer NOT NULL DEFAULT 1,hold text NOT NULL DEFAULT '');
CREATE TABLE IF NOT EXISTS workflow.decisions(
 uid text PRIMARY KEY,message_id bigint NOT NULL,chat_id text NOT NULL,
 task_id uuid REFERENCES business.tasks(id),action text NOT NULL,detail text NOT NULL,created_at timestamptz NOT NULL);
CREATE INDEX IF NOT EXISTS decision_task ON workflow.decisions(task_id,message_id);
CREATE TABLE IF NOT EXISTS workflow.context(
 uid text PRIMARY KEY,message_id bigint NOT NULL,chat_id text NOT NULL,sender_id text NOT NULL,
 task_id uuid REFERENCES business.tasks(id),ts bigint NOT NULL,artifact text,version_uid text);
CREATE INDEX IF NOT EXISTS context_chat ON workflow.context(chat_id,sender_id,ts);
CREATE TABLE IF NOT EXISTS workflow.artifacts(
 task_id uuid NOT NULL REFERENCES business.tasks(id),kind text NOT NULL,uid text NOT NULL,
 sender_id text NOT NULL,ts bigint NOT NULL,PRIMARY KEY(task_id,kind));
CREATE TABLE IF NOT EXISTS workflow.outbox(
 id bigserial PRIMARY KEY,task_id uuid NOT NULL REFERENCES business.tasks(id),
 version bigint NOT NULL,source_uid text NOT NULL,before_status text NOT NULL,target_status text NOT NULL,
 state text NOT NULL DEFAULT 'pending',attempts integer NOT NULL DEFAULT 0,next_attempt double precision NOT NULL DEFAULT 0,
 receipt text,error text NOT NULL DEFAULT '',created_at timestamptz NOT NULL,updated_at timestamptz NOT NULL,
 UNIQUE(task_id,version),FOREIGN KEY(task_id,version) REFERENCES business.status_history(task_id,version));

CREATE INDEX IF NOT EXISTS videos_source_message_uid_idx ON business.videos(source_message_uid);
CREATE TABLE IF NOT EXISTS workflow.video_observations(
 source_uid text PRIMARY KEY,video_id uuid NOT NULL UNIQUE REFERENCES business.videos(id),
 message_id bigint NOT NULL UNIQUE,chat_id text NOT NULL,sender_id text NOT NULL,sent_at bigint NOT NULL,
 report_stamp text NOT NULL DEFAULT 'missing',file_stamp text NOT NULL DEFAULT '',
 metadata text NOT NULL DEFAULT '{}',last_error text NOT NULL DEFAULT '',updated_at timestamptz NOT NULL DEFAULT now());

CREATE OR REPLACE VIEW workflow.video_inventory AS
SELECT v.id AS video_id,o.message_id,o.source_uid,o.chat_id,o.sender_id,
 to_timestamp(o.sent_at) AS sent_at,b.business_id AS work_id,t.title,
 v.task_id,v.kind,v.download_status,v.storage_path,v.size_bytes,v.duration_ms,v.sha256,
 o.last_error,o.updated_at
FROM workflow.video_observations o JOIN business.videos v ON v.id=o.video_id
LEFT JOIN business.tasks t ON t.id=v.task_id LEFT JOIN workflow.bindings b ON b.task_id=t.id;
COMMENT ON VIEW workflow.video_inventory IS '视频来源、已核对的作品归属与原件校验结果；未确认作品时 task_id 留空';

CREATE OR REPLACE VIEW workflow.task_progress AS
SELECT b.business_id AS work_id,t.id AS task_id,coalesce(d.display_name,l.doctor,b.doctor) AS doctor,t.title,t.content_type,t.status,t.status_version,
 h.change_source,h.source_message_uid,h.changed_at,t.updated_at,b.record_id AS feishu_record_id,b.hold,
 CASE WHEN b.task_id IS NULL THEN 'local_only' ELSE o.state END AS feishu_sync_state,o.error AS feishu_sync_error
FROM business.tasks t LEFT JOIN workflow.bindings b ON b.task_id=t.id
LEFT JOIN business.doctors d ON d.person_id=t.doctor_id LEFT JOIN workflow.local_tasks l ON l.task_id=t.id
LEFT JOIN business.status_history h ON h.task_id=t.id AND h.version=t.status_version
LEFT JOIN workflow.outbox o ON o.task_id=t.id AND o.version=t.status_version
WHERE b.task_id IS NULL OR b.enabled=1 OR NOT EXISTS(
 SELECT 1 FROM workflow.bindings active WHERE active.enabled=1 AND active.business_id<>''
 AND active.business_id=b.business_id AND active.doctor=b.doctor AND active.task_id<>b.task_id);

CREATE OR REPLACE VIEW workflow.recent_decisions AS
SELECT d.message_id,d.chat_id,b.business_id AS work_id,coalesce(p.display_name,l.doctor,b.doctor) AS doctor,t.title,d.action,
 coalesce(d.detail::jsonb->'outcome'->>'reason',d.detail::jsonb->'decision'->>'reason') AS reason,
 d.uid AS source_message_uid,d.created_at
FROM workflow.decisions d LEFT JOIN workflow.bindings b ON b.task_id=d.task_id
LEFT JOIN business.tasks t ON t.id=d.task_id LEFT JOIN workflow.local_tasks l ON l.task_id=t.id
LEFT JOIN business.doctors p ON p.person_id=t.doctor_id;
CREATE OR REPLACE VIEW workflow.document_inventory AS
SELECT f.id AS file_id,o.message_id,o.source_uid,o.chat_id,to_timestamp(o.sent_at) AS sent_at,
 f.task_id,t.title,f.filename,f.kind,f.download_status,f.storage_path,f.sha256,o.reason,o.updated_at
FROM workflow.document_observations o JOIN business.files f ON f.id=o.file_id
LEFT JOIN business.tasks t ON t.id=f.task_id;
COMMENT ON SCHEMA workflow IS '状态机运行断点、消息判断和飞书同步记录；与 business 同库事务';
COMMENT ON VIEW workflow.task_progress IS '当前有效作品状态、来源消息和飞书同步结果；停用绑定保留在原表中';
COMMENT ON VIEW workflow.recent_decisions IS '收到新消息后的判断，含未变更原因';
COMMENT ON VIEW workflow.document_inventory IS '已收到的文档及其任务关联；待下载不代表原件已获取';
COMMIT;
