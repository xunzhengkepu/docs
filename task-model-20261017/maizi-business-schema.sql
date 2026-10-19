-- Current task-centred design, 2026-10-19. Run once in an EMPTY dedicated database.

-- psql -v ON_ERROR_STOP=1 -f maizi-business-schema.sql

BEGIN;

CREATE SCHEMA business;

SET LOCAL search_path = business, pg_catalog;

CREATE TABLE people (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  wechat_id text,
  wechat_label text,
  PRIMARY KEY (id)
);

COMMENT ON TABLE people IS '一个人的共同身份';

COMMENT ON COLUMN people.id IS '人员编号';

COMMENT ON COLUMN people.name IS '姓名或可识别称呼；未实名时可用原昵称';

COMMENT ON COLUMN people.wechat_id IS '微信稳定账号标识；已知值唯一';

COMMENT ON COLUMN people.wechat_label IS '微信昵称或备注';

CREATE TABLE doctors (
  person_id uuid NOT NULL,
  display_name text,
  follower_count bigint,
  published_video_count bigint,
  stats_platform text,
  stats_updated_at timestamptz,
  PRIMARY KEY (person_id)
);

COMMENT ON TABLE doctors IS 'people 中具有医生身份的人';

COMMENT ON COLUMN doctors.person_id IS '对应 people.id';

COMMENT ON COLUMN doctors.display_name IS '医生账号或对外展示名称';

COMMENT ON COLUMN doctors.follower_count IS '主要账号粉丝数；未知不填0';

COMMENT ON COLUMN doctors.published_video_count IS '该账号已发布视频数，不是本系统任务数';

COMMENT ON COLUMN doctors.stats_platform IS '这组数字所属平台；暂按一个主要账号';

COMMENT ON COLUMN doctors.stats_updated_at IS '统计对应的采集时间';

CREATE TABLE employees (
  person_id uuid NOT NULL,
  work_roles text[],
  is_active boolean,
  PRIMARY KEY (person_id)
);

COMMENT ON TABLE employees IS 'people 中的员工身份';

COMMENT ON COLUMN employees.person_id IS '对应 people.id';

COMMENT ON COLUMN employees.work_roles IS '文案、剪辑、运营等，可多个；不是每项任务的实际分工';

COMMENT ON COLUMN employees.is_active IS '是否仍参与工作；未知可空，不能因长期未发言推断离职';

CREATE TABLE company_contacts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  person_id uuid NOT NULL,
  company_id uuid NOT NULL,
  role text,
  PRIMARY KEY (id)
);

COMMENT ON TABLE company_contacts IS '一个人与一家公司之间的任职或对接身份';

COMMENT ON COLUMN company_contacts.id IS '记录编号';

COMMENT ON COLUMN company_contacts.person_id IS '对应 people.id';

COMMENT ON COLUMN company_contacts.company_id IS '对应 companies.id';

COMMENT ON COLUMN company_contacts.role IS '对接、审核等职责';

CREATE TABLE companies (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  PRIMARY KEY (id)
);

COMMENT ON TABLE companies IS '一家公司或合作机构';

COMMENT ON COLUMN companies.id IS '公司编号';

COMMENT ON COLUMN companies.name IS '公司名称';

CREATE TABLE doctor_companies (
  doctor_id uuid NOT NULL,
  company_id uuid NOT NULL,
  relationship text,
  PRIMARY KEY (doctor_id, company_id)
);

COMMENT ON TABLE doctor_companies IS '一位医生与一家公司的实际合作关系';

COMMENT ON COLUMN doctor_companies.doctor_id IS '对应 doctors.person_id';

COMMENT ON COLUMN doctor_companies.company_id IS '对应 companies.id';

COMMENT ON COLUMN doctor_companies.relationship IS '合作类型或简短说明；不能由项目参与自动推断';

CREATE TABLE projects (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  requirements text,
  source_message_uid text,
  PRIMARY KEY (id)
);

COMMENT ON TABLE projects IS '一个明确的合作项目';

COMMENT ON COLUMN projects.id IS '项目编号';

COMMENT ON COLUMN projects.name IS '项目名称';

COMMENT ON COLUMN projects.requirements IS '已经明确的合作要求；不要求员工补写';

COMMENT ON COLUMN projects.source_message_uid IS '相关要求的来源消息；非群聊来源可空';

CREATE TABLE project_people (
  project_id uuid NOT NULL,
  person_id uuid NOT NULL,
  roles text[],
  PRIMARY KEY (project_id, person_id)
);

COMMENT ON TABLE project_people IS '一个人在某项目中承担的身份或分工';

COMMENT ON COLUMN project_people.project_id IS '对应 projects.id';

COMMENT ON COLUMN project_people.person_id IS '对应 people.id';

COMMENT ON COLUMN project_people.roles IS '项目医生、文案、剪辑、运营、客户对接等';

CREATE TABLE tasks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  doctor_id uuid,
  project_id uuid,
  content_type text NOT NULL DEFAULT '未知',
  status text NOT NULL DEFAULT '待准备',
  status_version bigint NOT NULL DEFAULT 1,
  note text,
  updated_by uuid,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (id)
);

COMMENT ON TABLE tasks IS '一项从明确需求到发布的制作工作；本模型核心';

COMMENT ON COLUMN tasks.id IS '任务编号';

COMMENT ON COLUMN tasks.title IS '任务名称，可先用暂定标题';

COMMENT ON COLUMN tasks.doctor_id IS '对应 doctors.person_id；归属未确定时可空';

COMMENT ON COLUMN tasks.project_id IS '对应 projects.id；日常内容可无项目';

COMMENT ON COLUMN tasks.content_type IS '科普、患教、其他、未知；不得凭猜测填患教';

COMMENT ON COLUMN tasks.status IS '当前进度，可由明确证据推进或人工更正';

COMMENT ON COLUMN tasks.status_version IS '当前状态的序号；从1开始，每次状态实际变化加1，对应本任务最新历史的 version';

COMMENT ON COLUMN tasks.note IS '可选短说明：需求、修改意见或卡点；优先展示原话，不要求手填';

COMMENT ON COLUMN tasks.updated_by IS '对应 people.id；仅人工操作填操作人，自动处理留空';

COMMENT ON COLUMN tasks.created_at IS '任务创建时间';

COMMENT ON COLUMN tasks.updated_at IS '最近一次更新的时间，不是业务发生时间';

CREATE TABLE status_history (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL,
  version bigint NOT NULL,
  from_status text,
  to_status text NOT NULL,
  changed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  change_source text NOT NULL,
  changed_by uuid,
  source_message_uid text,
  PRIMARY KEY (id)
);

COMMENT ON TABLE status_history IS '一次已生效的任务状态改动；人工和自动都记录';

COMMENT ON COLUMN status_history.id IS '状态历史编号';

COMMENT ON COLUMN status_history.task_id IS '对应 tasks.id';

COMMENT ON COLUMN status_history.version IS '本任务内的状态序号；从1开始递增，task_id＋version 唯一；不是跨任务编号';

COMMENT ON COLUMN status_history.from_status IS '修改前状态；首次记录可空';

COMMENT ON COLUMN status_history.to_status IS '修改后状态';

COMMENT ON COLUMN status_history.changed_at IS '状态写入时间，不代表业务实际发生时间';

COMMENT ON COLUMN status_history.change_source IS '自动识别、人工修改、导入';

COMMENT ON COLUMN status_history.changed_by IS '对应 people.id；仅人工操作填写，自动修改可空';

COMMENT ON COLUMN status_history.source_message_uid IS '本次修改依据的微信消息，无对应消息可空';

CREATE TABLE videos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  task_id uuid,
  source_message_uid text,
  storage_path text,
  download_status text NOT NULL DEFAULT '待下载',
  sha256 text,
  kind text NOT NULL DEFAULT '未知',
  size_bytes bigint,
  duration_ms bigint,
  PRIMARY KEY (id)
);

COMMENT ON TABLE videos IS '属于任务的一段原片或一份成片；没有视频之间的关联';

COMMENT ON COLUMN videos.id IS '文件记录编号';

COMMENT ON COLUMN videos.task_id IS '所属 tasks.id；不确定先留空';

COMMENT ON COLUMN videos.source_message_uid IS '首次来源消息，用于查发送者、群、时间和上下文；导入无消息可空';

COMMENT ON COLUMN videos.storage_path IS '实际可用的本地或归档路径；未下载可空';

COMMENT ON COLUMN videos.download_status IS '待下载、下载中、已下载、失败、文件缺失；链接资料可无需下载';

COMMENT ON COLUMN videos.sha256 IS '下载后计算的文件内容哈希；未知留空';

COMMENT ON COLUMN videos.kind IS '原片、成片、参考视频、未知；默认未知';

COMMENT ON COLUMN videos.size_bytes IS '完整视频文件字节数';

COMMENT ON COLUMN videos.duration_ms IS '视频时长，毫秒';

CREATE TABLE files (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  task_id uuid,
  source_message_uid text,
  storage_path text,
  download_status text NOT NULL DEFAULT '待下载',
  sha256 text,
  filename text,
  kind text NOT NULL DEFAULT '未知',
  external_url text,
  PRIMARY KEY (id)
);

COMMENT ON TABLE files IS '脚本、大纲、封面等非视频文件；没有文件之间的关联';

COMMENT ON COLUMN files.id IS '文件记录编号';

COMMENT ON COLUMN files.task_id IS '所属 tasks.id；不确定先留空';

COMMENT ON COLUMN files.source_message_uid IS '首次来源消息，用于查发送者、群、时间和上下文；导入无消息可空';

COMMENT ON COLUMN files.storage_path IS '实际可用的本地或归档路径；未下载可空';

COMMENT ON COLUMN files.download_status IS '待下载、下载中、已下载、失败、文件缺失；链接资料可无需下载';

COMMENT ON COLUMN files.sha256 IS '下载后计算的文件内容哈希；未知留空';

COMMENT ON COLUMN files.filename IS '真实附件名；纯链接没有名称时可空';

COMMENT ON COLUMN files.kind IS '脚本、大纲、封面、发布文案、参考资料、其他、未知';

COMMENT ON COLUMN files.external_url IS '腾讯文档、飞书等外部资料地址';

CREATE TABLE publications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL,
  video_id uuid,
  platform text NOT NULL,
  status text NOT NULL DEFAULT '待安排',
  scheduled_at timestamptz,
  published_at timestamptz,
  url text,
  platform_video_id text,
  source_message_uid text,
  confirmed_by uuid,
  confirmed_at timestamptz,
  view_count bigint,
  stats_updated_at timestamptz,
  PRIMARY KEY (id)
);

COMMENT ON TABLE publications IS '任务在一个平台的一次发布；多平台和重发分别记录';

COMMENT ON COLUMN publications.id IS '发布记录编号';

COMMENT ON COLUMN publications.task_id IS '所属 tasks.id';

COMMENT ON COLUMN publications.video_id IS '对应 videos.id；未能确定具体文件版本时可空';

COMMENT ON COLUMN publications.platform IS '发布平台';

COMMENT ON COLUMN publications.status IS '待安排、已定时、已发布、已取消、已下架';

COMMENT ON COLUMN publications.scheduled_at IS '实际设置的定时；“计划明天发”不算已设置定时';

COMMENT ON COLUMN publications.published_at IS '实际发布时间；不是改表时间';

COMMENT ON COLUMN publications.url IS '实际发布链接；人工已确认发布时允许待补';

COMMENT ON COLUMN publications.platform_video_id IS '平台上的视频编号，用于去重';

COMMENT ON COLUMN publications.source_message_uid IS '支持该安排或发布结果的消息';

COMMENT ON COLUMN publications.confirmed_by IS '对应 people.id；仅人工确认时填写';

COMMENT ON COLUMN publications.confirmed_at IS '系统记下本次确认的时间';

COMMENT ON COLUMN publications.view_count IS '这次发布最近一次获取到的播放／浏览量；非负整数，未知留空，不填0';

COMMENT ON COLUMN publications.stats_updated_at IS '该浏览量对应的统计时间；与 view_count 一起更新，不代表发布时间';

ALTER TABLE doctors ADD FOREIGN KEY (person_id) REFERENCES people (id);

ALTER TABLE employees ADD FOREIGN KEY (person_id) REFERENCES people (id);

ALTER TABLE company_contacts ADD FOREIGN KEY (person_id) REFERENCES people (id);

ALTER TABLE company_contacts ADD FOREIGN KEY (company_id) REFERENCES companies (id);

ALTER TABLE doctor_companies ADD FOREIGN KEY (doctor_id) REFERENCES doctors (person_id);

ALTER TABLE doctor_companies ADD FOREIGN KEY (company_id) REFERENCES companies (id);

ALTER TABLE project_people ADD FOREIGN KEY (project_id) REFERENCES projects (id);

ALTER TABLE project_people ADD FOREIGN KEY (person_id) REFERENCES people (id);

ALTER TABLE tasks ADD FOREIGN KEY (doctor_id) REFERENCES doctors (person_id);

ALTER TABLE tasks ADD FOREIGN KEY (project_id) REFERENCES projects (id);

ALTER TABLE tasks ADD FOREIGN KEY (updated_by) REFERENCES people (id);

ALTER TABLE status_history ADD FOREIGN KEY (task_id) REFERENCES tasks (id);

ALTER TABLE status_history ADD FOREIGN KEY (changed_by) REFERENCES people (id);

ALTER TABLE videos ADD FOREIGN KEY (task_id) REFERENCES tasks (id);

ALTER TABLE files ADD FOREIGN KEY (task_id) REFERENCES tasks (id);

ALTER TABLE publications ADD FOREIGN KEY (task_id) REFERENCES tasks (id);

ALTER TABLE publications ADD FOREIGN KEY (video_id) REFERENCES videos (id);

ALTER TABLE publications ADD FOREIGN KEY (confirmed_by) REFERENCES people (id);

ALTER TABLE people ADD UNIQUE (wechat_id);

ALTER TABLE company_contacts ADD UNIQUE (person_id, company_id);

ALTER TABLE status_history ADD UNIQUE (task_id, version);

ALTER TABLE tasks ADD CHECK (status_version > 0);

ALTER TABLE status_history ADD CHECK (version > 0);

ALTER TABLE status_history ADD CHECK (change_source IN ('自动识别','人工修改','导入'));

ALTER TABLE status_history ADD CHECK ((change_source = '人工修改' AND changed_by IS NOT NULL) OR (change_source <> '人工修改' AND changed_by IS NULL));

ALTER TABLE status_history ADD CHECK (change_source <> '自动识别' OR nullif(btrim(source_message_uid),'') IS NOT NULL);

ALTER TABLE status_history ADD CHECK ((version=1 AND from_status IS NULL) OR (version>1 AND from_status IS NOT NULL AND from_status<>to_status));

CREATE UNIQUE INDEX status_history_auto_message ON status_history(task_id,source_message_uid) WHERE change_source='自动识别';

ALTER TABLE videos ADD UNIQUE (id, task_id);

ALTER TABLE publications ADD FOREIGN KEY (video_id, task_id) REFERENCES videos(id, task_id);

ALTER TABLE publications ADD CHECK (view_count >= 0);

ALTER TABLE publications ADD CHECK ((view_count IS NULL) = (stats_updated_at IS NULL));

ALTER TABLE doctors ADD CHECK (follower_count >= 0 AND published_video_count >= 0);

ALTER TABLE videos ADD CHECK (size_bytes >= 0 AND duration_ms >= 0);

ALTER TABLE videos ADD CHECK (kind IN ('原片','成片','参考视频','未知'));

ALTER TABLE files ADD CHECK (kind IN ('脚本','大纲','封面','发布文案','参考资料','其他','未知'));

ALTER TABLE publications ADD CHECK (status IN ('待安排','已定时','已发布','已取消','已下架'));

ALTER TABLE videos ADD CHECK (download_status IN ('待下载','下载中','已下载','失败','文件缺失'));

ALTER TABLE videos ADD CHECK (sha256 IS NULL OR sha256 ~ '^[0-9a-f]{64}$');

ALTER TABLE videos ADD CHECK (download_status <> '已下载' OR nullif(btrim(storage_path),'') IS NOT NULL);

CREATE UNIQUE INDEX videos_task_hash ON videos(task_id,sha256) WHERE task_id IS NOT NULL AND sha256 IS NOT NULL;

ALTER TABLE files ADD CHECK (download_status IN ('待下载','下载中','已下载','失败','文件缺失','无需下载'));

ALTER TABLE files ADD CHECK (sha256 IS NULL OR sha256 ~ '^[0-9a-f]{64}$');

ALTER TABLE files ADD CHECK (download_status <> '已下载' OR nullif(btrim(storage_path),'') IS NOT NULL);

CREATE UNIQUE INDEX files_task_hash ON files(task_id,sha256) WHERE task_id IS NOT NULL AND sha256 IS NOT NULL;

CREATE INDEX tasks_project_id_idx ON tasks(project_id);

CREATE INDEX videos_task_id_idx ON videos(task_id);

CREATE INDEX files_task_id_idx ON files(task_id);

CREATE INDEX publications_task_id_idx ON publications(task_id);

-- Deferred validation makes an incomplete task/history write fail at commit.
CREATE FUNCTION business.check_status_chain() RETURNS trigger
LANGUAGE plpgsql SET search_path = business, pg_catalog AS $$
DECLARE tid uuid; t tasks%ROWTYPE; last_row status_history%ROWTYPE;
BEGIN
  IF TG_TABLE_NAME = 'tasks' THEN tid := NEW.id; ELSE tid := NEW.task_id; END IF;
  SELECT * INTO t FROM tasks WHERE id=tid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Task missing'; END IF;
  SELECT * INTO last_row FROM status_history WHERE task_id=tid ORDER BY version DESC LIMIT 1;
  IF NOT FOUND OR last_row.version<>t.status_version OR last_row.to_status<>t.status THEN
    RAISE EXCEPTION 'Task status/version must match latest history' USING ERRCODE='23514';
  END IF;
  IF (SELECT count(*) FROM status_history WHERE task_id=tid) <> t.status_version THEN
    RAISE EXCEPTION 'Status versions must be continuous from 1' USING ERRCODE='23514';
  END IF;
  IF EXISTS (
    SELECT 1 FROM status_history h JOIN status_history p ON p.task_id=h.task_id AND p.version=h.version-1
    WHERE h.task_id=tid AND h.from_status IS DISTINCT FROM p.to_status
  ) THEN RAISE EXCEPTION 'Status history chain is inconsistent' USING ERRCODE='23514'; END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER task_status_consistent AFTER INSERT OR UPDATE ON business.tasks
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION business.check_status_chain();
CREATE CONSTRAINT TRIGGER history_status_consistent AFTER INSERT ON business.status_history
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION business.check_status_chain();

CREATE FUNCTION business.protect_history() RETURNS trigger
LANGUAGE plpgsql AS $$ BEGIN
 RAISE EXCEPTION 'Status history is append-only; correct it with a new change';
END $$;
CREATE TRIGGER history_append_only BEFORE UPDATE OR DELETE OR TRUNCATE ON business.status_history
FOR EACH STATEMENT EXECUTE FUNCTION business.protect_history();

CREATE FUNCTION business.touch_task() RETURNS trigger
LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at := clock_timestamp(); RETURN NEW; END $$;
CREATE TRIGGER task_updated_at BEFORE UPDATE ON business.tasks
FOR EACH ROW EXECUTE FUNCTION business.touch_task();

CREATE FUNCTION business.create_task(
 p_title text, p_source text, p_actor uuid DEFAULT NULL, p_message text DEFAULT NULL,
 p_project uuid DEFAULT NULL, p_doctor uuid DEFAULT NULL, p_status text DEFAULT '待准备'
) RETURNS uuid LANGUAGE plpgsql SET search_path = business, pg_catalog AS $$
DECLARE tid uuid;
BEGIN
 INSERT INTO tasks(title,project_id,doctor_id,status,updated_by)
 VALUES(p_title,p_project,p_doctor,p_status,p_actor) RETURNING id INTO tid;
 INSERT INTO status_history(task_id,version,from_status,to_status,change_source,changed_by,source_message_uid)
 VALUES(tid,1,NULL,p_status,p_source,p_actor,p_message);
 RETURN tid;
END $$;

-- Expected version is mandatory. Replayed automatic messages return without applying again.
-- Analysis/model version deliberately does NOT appear in the business idempotency key.
CREATE FUNCTION business.change_task_status(
 p_task uuid, p_expected_version bigint, p_status text, p_source text,
 p_actor uuid DEFAULT NULL, p_message text DEFAULT NULL
) RETURNS bigint LANGUAGE plpgsql SET search_path = business, pg_catalog AS $$
DECLARE t tasks%ROWTYPE; latest_source text;
BEGIN
 SELECT * INTO t FROM tasks WHERE id=p_task FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Unknown task' USING ERRCODE='P0002'; END IF;
 IF p_source IS NULL OR p_source NOT IN ('自动识别','人工修改','导入') THEN RAISE EXCEPTION 'Invalid source'; END IF;
 IF (p_source='人工修改') <> (p_actor IS NOT NULL) THEN RAISE EXCEPTION 'Actor must identify an actual manual operator'; END IF;
 IF p_source='自动识别' AND nullif(btrim(p_message),'') IS NULL THEN RAISE EXCEPTION 'Automatic status requires a message'; END IF;
 IF p_source='自动识别' AND EXISTS(SELECT 1 FROM status_history WHERE task_id=p_task AND change_source='自动识别' AND source_message_uid=p_message) THEN
   RETURN t.status_version;
 END IF;
 IF p_expected_version IS DISTINCT FROM t.status_version THEN RAISE EXCEPTION 'Stale status version; reread task' USING ERRCODE='40001'; END IF;
 IF p_status IS NULL OR btrim(p_status)='' THEN RAISE EXCEPTION 'Status is required'; END IF;
 IF p_status=t.status THEN RETURN t.status_version; END IF;
 SELECT change_source INTO latest_source FROM status_history WHERE task_id=p_task AND version=t.status_version;
 IF p_source='自动识别' AND latest_source='人工修改' THEN RAISE EXCEPTION 'Manual status requires human confirmation before automatic changes'; END IF;
 UPDATE tasks SET status=p_status,status_version=t.status_version+1,updated_by=p_actor WHERE id=p_task;
 INSERT INTO status_history(task_id,version,from_status,to_status,change_source,changed_by,source_message_uid)
 VALUES(p_task,t.status_version+1,t.status,p_status,p_source,p_actor,p_message);
 RETURN t.status_version+1;
END $$;


COMMIT;
