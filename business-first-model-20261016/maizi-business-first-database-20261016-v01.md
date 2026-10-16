# 麦子工作台：数据结构与业务结构

2026-10-16 v01。设计稿，未实施迁移。人员只用 people；共13张表。员工可直接改状态、跳步与退回，系统建议不覆盖人工确认。微信自动下载替代云盘收片。

[网页与放大图](maizi-business-first-database-20261016-v01.html)

## 完整数据结构 ERD

```mermaid
erDiagram
    people ||--o{ people_companies : "人员"
    companies ||--o{ people_companies : "公司"
    projects ||--o{ project_companies : "项目"
    companies ||--o{ project_companies : "合作方"
    projects ||--o{ project_people : "项目"
    people ||--o{ project_people : "参与人"
    people ||--o{ videos : "医生"
    people o|--o{ videos : "总负责人可空"
    projects o|--o{ videos : "项目可空"
    videos ||--o{ status_changes : "已生效修改"
    people o|--o{ status_changes : "修改人"
    videos o|--o{ files : "归属可待核实"
    people o|--o{ files : "检查人"
    videos ||--o{ reviews : "审核要求"
    files o|--o{ reviews : "具体版本可待补"
    people o|--o{ reviews : "审核人"
    people o|--o{ reviews : "确认记录人"
    files ||--o{ deliveries : "交付版本"
    people ||--o{ deliveries : "接收人"
    people ||--o{ deliveries : "记录人"
    videos ||--o{ publications : "定时及发布"
    files o|--o{ publications : "发布版本可待补"
    people o|--o{ publications : "确认人"
    videos o|--o{ todos : "关联视频可空"
    projects o|--o{ todos : "关联项目可空"
    people o|--o{ todos : "负责人"
    people o|--o{ todos : "提出人"
    people o|--o{ todos : "处理人"
    people["人员 · people"] {
        string id PK
        string name
        string roles
        string wechat_id
    }
    companies["公司 · companies"] {
        string id PK
        string name
    }
    projects["项目 · projects"] {
        string id PK
        string name
        string requirements
    }
    people_companies["人员与公司 · people_companies"] {
        string person_id PK,FK
        string company_id PK,FK
        string relationship
    }
    project_companies["项目与公司 · project_companies"] {
        string project_id PK,FK
        string company_id PK,FK
        string role
    }
    project_people["项目参与人 · project_people"] {
        string project_id PK,FK
        string person_id PK,FK
        string roles
    }
    videos["视频 · videos"] {
        string id PK
        string doctor_id FK
        string project_id FK
        string owner_id FK
        string content_type
        string current_status
        int status_revision
        datetime planned_publish_at
        string evidence_status
    }
    status_changes["状态修改历史 · status_changes"] {
        string id PK
        string video_id FK
        string actor_id FK
        string from_status
        string to_status
        int revision
        datetime changed_at
        string source
    }
    files["文件与版本 · files"] {
        string id PK
        string video_id FK
        string checked_by FK
        string kind
        string version_label
        string source_message_uids
        string archive_path
        string sha256
        string download_status
        string availability
    }
    reviews["审核与确认 · reviews"] {
        string id PK
        string video_id FK
        string file_id FK
        string reviewer_id FK
        string recorded_by FK
        int round_no
        int order_group
        boolean required
        string result
    }
    deliveries["交付 · deliveries"] {
        string id PK
        string file_id FK
        string recipient_id FK
        string recorded_by FK
        datetime delivered_at
    }
    publications["定时与发布 · publications"] {
        string id PK
        string video_id FK
        string file_id FK
        string confirmed_by FK
        string platform
        string status
        datetime scheduled_at
        datetime published_at
        string url
    }
    todos["待办与系统建议 · todos"] {
        string id PK
        string video_id FK
        string project_id FK
        string assignee_id FK
        string requester_id FK
        string resolved_by FK
        string kind
        string status
        string proposed_status
        int based_on_revision
    }
```

[SVG 大图](maizi-business-first-database-20261016-v01-erd.svg) · [Mermaid 源文件](maizi-business-first-database-20261016-v01-erd.mmd)

## 人员与合作关系

```mermaid
erDiagram
    people ||--o{ people_companies : "人员"
    companies ||--o{ people_companies : "公司"
    projects ||--o{ project_companies : "项目"
    companies ||--o{ project_companies : "合作方"
    projects ||--o{ project_people : "项目"
    people ||--o{ project_people : "参与人"
    people ||--o{ videos : "医生"
    people o|--o{ videos : "总负责人可空"
    projects o|--o{ videos : "项目可空"
    people["人员 · people"] {
        string id PK
        string name
        string roles
        string wechat_id
    }
    companies["公司 · companies"] {
        string id PK
        string name
    }
    projects["项目 · projects"] {
        string id PK
        string name
        string requirements
    }
    people_companies["人员与公司 · people_companies"] {
        string person_id PK,FK
        string company_id PK,FK
        string relationship
    }
    project_companies["项目与公司 · project_companies"] {
        string project_id PK,FK
        string company_id PK,FK
        string role
    }
    project_people["项目参与人 · project_people"] {
        string project_id PK,FK
        string person_id PK,FK
        string roles
    }
    videos["视频 · videos"] {
        string id PK
        string doctor_id FK
        string project_id FK
        string owner_id FK
        string content_type
        string current_status
        int status_revision
        datetime planned_publish_at
        string evidence_status
    }
```

[SVG 大图](maizi-business-first-database-20261016-v01-relations.svg) · [Mermaid 源文件](maizi-business-first-database-20261016-v01-relations.mmd)

## 视频制作数据结构

```mermaid
erDiagram
    videos ||--o{ status_changes : "已生效修改"
    videos o|--o{ files : "归属可待核实"
    videos ||--o{ reviews : "审核要求"
    files o|--o{ reviews : "具体版本可待补"
    files ||--o{ deliveries : "交付版本"
    videos ||--o{ publications : "定时及发布"
    files o|--o{ publications : "发布版本可待补"
    videos o|--o{ todos : "关联视频可空"
    videos["视频 · videos"] {
        string id PK
        string doctor_id FK
        string project_id FK
        string owner_id FK
        string content_type
        string current_status
        int status_revision
        datetime planned_publish_at
        string evidence_status
    }
    status_changes["状态修改历史 · status_changes"] {
        string id PK
        string video_id FK
        string actor_id FK
        string from_status
        string to_status
        int revision
        datetime changed_at
        string source
    }
    files["文件与版本 · files"] {
        string id PK
        string video_id FK
        string checked_by FK
        string kind
        string version_label
        string source_message_uids
        string archive_path
        string sha256
        string download_status
        string availability
    }
    reviews["审核与确认 · reviews"] {
        string id PK
        string video_id FK
        string file_id FK
        string reviewer_id FK
        string recorded_by FK
        int round_no
        int order_group
        boolean required
        string result
    }
    deliveries["交付 · deliveries"] {
        string id PK
        string file_id FK
        string recipient_id FK
        string recorded_by FK
        datetime delivered_at
    }
    publications["定时与发布 · publications"] {
        string id PK
        string video_id FK
        string file_id FK
        string confirmed_by FK
        string platform
        string status
        datetime scheduled_at
        datetime published_at
        string url
    }
    todos["待办与系统建议 · todos"] {
        string id PK
        string video_id FK
        string project_id FK
        string assignee_id FK
        string requester_id FK
        string resolved_by FK
        string kind
        string status
        string proposed_status
        int based_on_revision
    }
```

[SVG 大图](maizi-business-first-database-20261016-v01-production.svg) · [Mermaid 源文件](maizi-business-first-database-20261016-v01-production.mmd)

## 业务主线

```mermaid
flowchart TD
 a["明确要做一条视频：需求、档期或初稿"] --> b["建立同一条视频记录"]
 b --> c["选题、大纲或脚本准备"]
 c --> d["按本次要求安排审核人"]
 d --> e["医生、客户、内部审核：可先后或同步"]
 e --> f{"本轮是否确认可以录制"}
 f -->|需要改| c
 f -->|确认| g["医生录制，在微信发送原片"]
 g --> h["自动下载并校验；能匹配的关联视频"]
 h --> i["剪辑检查素材是否够用"]
 i -->|缺片段或不可用| j["待办：补录或重传"]
 j --> g
 i -->|可开始| k["剪辑制作，在微信发送成片版本"]
 k --> l["按本次要求审片；新版本重新确认"]
 l -->|需要改| k
 l -->|确认| m["员工确认待发布；按约定交付终版"]
 m --> n{"实际怎么发布"}
 n -->|设置了定时| o["员工记录已定时及定时时间"]
 o --> p["实际发布后，员工记录已发布"]
 n -->|直接发布| p
 p --> q["发布链接或时间暂缺：单独标待补"]
 p --> r["视频制作发布完成"]
 r -.->|合作需要时| s["独立待办：提交后台数据等"]
 s --> t["办完后关闭待办，视频仍为已发布"]
 u["这是常见业务路径，不是必须逐格点击的闸门"] -.-> b
 u -.-> m
```

[SVG 大图](maizi-business-first-database-20261016-v01-flow.svg) · [Mermaid 源文件](maizi-business-first-database-20261016-v01-flow.mmd)

## 人工状态与自动建议

```mermaid
flowchart TD
 a["微信消息、本地下载文件"] --> b["保存事实和来源"]
 b --> c{"是否能判断具体视频和进度"}
 c -->|能| d["形成状态建议，不改当前状态"]
 c -->|不确定| e["保留未匹配事实，需要时待核实"]
 d --> f{"员工处理建议"}
 f -->|驳回| g["关闭建议，状态不变"]
 f -->|采纳| h["检查状态版本，防止旧建议覆盖新修改"]
 h -->|已变化| i["建议过期，重新核对"]
 h -->|仍一致| j["提交状态修改"]
 k["员工直接选状态：允许跳步、退回"] --> j
 j --> l["同一次保存：更新当前状态并追加修改历史"]
 l --> m["保存谁、何时、从哪改到哪、来源"]
 l --> n["缺链接或版本只标证据待补，不自动退回"]
```

[SVG 大图](maizi-business-first-database-20261016-v01-control.svg) · [Mermaid 源文件](maizi-business-first-database-20261016-v01-control.mmd)

## 微信收片与下载

```mermaid
flowchart TD
 a["微信收到视频消息"] --> b["保存稳定消息 uid，登记待下载"]
 b --> c["扫描微信本地视频目录"]
 c --> d{"完整视频已落盘并通过校验吗"}
 d -->|还没有或失败| e["等待或重试，下载状态单独记录"]
 e --> c
 d -->|通过| f["生成文件编号，计算哈希并归档"]
 f --> g{"能确定视频归属及文件类型吗"}
 g -->|不能| h["保留待分类或待关联，员工核对"]
 h --> i["关联同一条视频记录"]
 g -->|能| i
 i --> j{"文件类型"}
 j -->|原片| k["人工检查可用性及是否收齐"]
 k -->|缺内容或不可用| l["补录或重传待办"]
 l --> a
 k -->|可开始剪| m["建议待剪辑，员工确认或直接开剪"]
 j -->|成片| n["记录成片版本，建议待审片"]
 j -->|参考或其他| o["只存资料，不推进主状态"]
 m --> p["当前业务状态由员工确认；修改留历史"]
 n --> p
```

[SVG 大图](maizi-business-first-database-20261016-v01-intake.svg) · [Mermaid 源文件](maizi-business-first-database-20261016-v01-intake.mmd)

## 表的用途

| 表 | 一行代表什么 |
|---|---|
| `people`（人员） | 一个人 |
| `companies`（公司） | 一家公司 |
| `projects`（项目） | 一个合作项目 |
| `people_companies`（人员与公司） | 一个人与一家公司的关系 |
| `project_companies`（项目与公司） | 一个项目与一家公司的关系 |
| `project_people`（项目参与人） | 一个人在这个项目里的分工 |
| `videos`（视频） | 一条明确安排制作的视频，可以还没有初稿 |
| `status_changes`（状态修改历史） | 一次已经生效的状态修改 |
| `files`（文件与版本） | 一份通过微信收到的文件或具体版本 |
| `reviews`（审核与确认） | 一个具体审核对象的一项确认要求及结果 |
| `deliveries`（交付） | 把某版成片交给一个接收人 |
| `publications`（定时与发布） | 一条视频在某平台的一次发布安排或实际发布 |
| `todos`（待办与系统建议） | 一件待处理的事情，或一条尚未采纳的状态建议 |

## 关键规则

- 业务流程不是强制打卡顺序；人工推进可跳步和退回，每次生效修改追加历史。
- 收到消息、下载完整、素材够用、审核通过、实际发布是不同事实。
- 已定时与已发布分开，缺链接或文件只标证据待补。
- 文件无法对应内容时保留未匹配状态，不凭文件名或时间强行关联。
- 审核可先后或同步，新版本保留独立确认；历史缺版本不否认人工已确认进度。
- 发布后数据回收属于独立待办，按合作要求启用。
- 当前处理配置只覆盖一个群；本次发布文档未扩大范围或改变采集服务。