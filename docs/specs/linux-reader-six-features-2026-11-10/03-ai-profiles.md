# F3：多组 AI 配置与安全迁移

状态：多配置、独立密钥、迁移与设置交互已实现并通过自动验证；真实 Provider、备份恢复和用户验收待执行。顺序以 [总规格](README.md) 为准。

## 1. 基线、目标与范围

`lib/domain/ai/ai_models.dart` 的 `AiSettings` 当前是一份全局连接配置；`lib/core/database/drift_ai_settings_repository.dart` 读写 `app_settings`；`lib/core/security/security_keys.dart` 的旧密钥名称为 `ai.openai-compatible.apiKey`；`AiChatService` 按该单键读取。

新增命名配置，如“本地服务”“远程推理”“备用模型”，每组独立 endpoint、模型、参数与密钥。当前仍只支持已有 OpenAI-compatible 协议，不扩展供应商专有协议、本地模型下载、负载均衡或失败后自动切到另一组。

现有 AI 启用开关、确认发送偏好保持全局；Provider、baseUrl、model、temperature、maxTokens、streaming、systemPrompt 属于 profile。读取旧设置的默认值保留，不静默修复已损坏字段。

## 2. 交互规格

设置页 AI 分类顶部为命名配置选择器，邻近提供新建、复制、重命名、删除菜单，下面延续当前连接字段优先、高级参数折叠的布局。阅读器 AI 面板只提供轻量配置选择及进入设置，不重复整套表单。

| 操作 | 行为 |
| --- | --- |
| 新建 | 新 UUID，名称自动建议但可修改；endpoint/model 为空，密钥为空，不自动激活 |
| 复制 | 复制非敏感配置；默认不复制密钥。另选“复制密钥”须明确动作，成功后才显示密钥已配置 |
| 重命名 | 名称 trim 后 1–60 字符；活动配置保持 ID，请求/旧历史名称快照不变 |
| 选择配置 | 改 `activeProfileId`，即时保存；选择其他组不会保存当前表单草稿 |
| 保存并测试 | 只保存该组合法草稿，读取该组密钥，返回 profileId+revision 对应结果 |
| 删除非活动组 | 确认后逻辑删除并回收该组密钥；不影响活动组 |
| 删除活动组 | 同一确认中可选择替代组；无替代时 active=null、AI 全局关闭，保留其他草稿 |
| 所有配置为空 | AI 显示未配置状态；启用不能发出无效请求 |

同设置页生命周期内，每个 profile 保存独立 draft。切换后回到原组草稿仍在；离开设置且有未保存修改时按现有离开确认交互处理。外部配置更新对未触及字段合并，冲突字段明确提示，不覆盖用户输入。

已有 form controller 的操作互斥、字段校验、失败重试继续生效。不同组的连接测试结果不能串显示；修改 endpoint/model/key 后旧“连接成功”失效。测试操作不得修改用户的真实书籍上下文或发整书内容。

## 3. 领域与数据库

### 3.1 拟新增模型

`AiProfile(id,name,provider,baseUrl,model,temperature,maxTokens,streaming,systemPrompt,revision,createdAt,updatedAt,credentialState)`。

- `revision` 为每次持久配置/密钥身份变更递增的整数，初始 1；不等同时间戳，解决同毫秒更新。
- `credentialState` 是运行时读取结果：`configured/missing/unavailable/pendingCleanup`，不以数据库 bool 证明密钥确实存在。
- `AiGlobalSettings(enabled,activeProfileId?,confirmBeforeRequest)` 不含 endpoint 或 key。
- `AiRequestProfileSnapshot(profileId?,profileName,profileRevision?,provider,model,endpointOrigin,parameters)` 不含密钥；历史仅保存必要参数，不默认存完整 URL query、systemPrompt 或 header。

`AiProfileRepository` 提供 watch/list/get/create/update/delete/setActive；secret 操作经 `AiCredentialService`，不让 UI 拼 secure-store key 或访问 DAO。保存使用 expectedRevision 乐观校验，冲突返回 `profile_conflict`，不能最后写入吞掉外部修改。

### 3.2 v9 结构

| 结构 | 字段/约束 |
| --- | --- |
| `ai_profiles` | UUID id；name、provider、base_url、model、temperature、max_tokens、streaming、system_prompt、revision、created_at、updated_at、deleted_at? |
| `app_settings` | 保留 `ai.enabled`、`privacy.confirmBeforeAiRequest`；新增 `ai.activeProfileId` 与 `ai.profileMigrationState` |
| `ai_credential_operations` | id、profile_id、operation、phase、expected_revision、owner_session_id、created_at、updated_at；只记录操作身份与状态，不记录密钥 |
| `ai_conversations` | 新增可空 `profile_id` 和 `profile_snapshot` JSON，删除 profile 后历史不级联消失 |

profile_snapshot JSON v1：含上述安全快照与 version=1；缺字段的旧历史显示已有 provider/model，不假造当时用的默认 profile。未知新版本保持原始记录可导出并显示暂不能解析，不隐式换成当前配置。

baseUrl 规范化延续现有拼接逻辑，拒绝 userinfo 和 query 中凭证；非 HTTPS 的本机服务仍可用，并给明确传输提示，不能为了多配置破坏本地服务。参数范围复用现有字段校验。

## 4. Secure storage 契约

新密钥 key：`ai.profile.<UUID>.apiKey`，数据库、备份、导出、日志不含密钥。读取错误不等于没有密钥；UI 区分系统密钥服务不可用和未配置。不得给不同 profile 共用旧全局 key。

数据库与 secure storage 无法跨系统事务，所有修改由 credential service 串行处理该 profile，journal 可在重启时恢复。profile 尚有未完成 credential operation 时禁止新请求使用它；已捕获凭证的在途请求按第 6 节完成。

DB 层限制每个 profile 至多一个未终结 credential operation，使用事务领取的 operation token/expectedRevision，不能只靠本进程 mutex。多个应用实例冲突时后发操作显示处理中，不并行覆盖 secure-store key；恢复前确认原 owner 已不再活跃。

2026-11-12 实现采用数据库旁的单一 OS 文件锁，加同 isolate 内按规范化数据库路径排队，
覆盖迁移、secret 操作和恢复的完整窗口。设置操作低频，统一锁避免迁移锁和 profile 锁的交叉顺序。
journal 记录 owner_session_id；进程崩溃后 OS 释放锁，恢复者取得锁才能推进。
锁文件不含 secret、不进备份，不凭 PID 存在与否猜 owner 状态；其他进程占锁超过 5 秒提示重试。
内存测试库使用实例排队，不宣称跨进程保护；未来若在其他 isolate 操作凭证，需统一转发到拥有该服务的 isolate。

### 4.1 从单配置迁移

1. v9 SQL 升级只创建表/列，不调用系统密钥服务。应用初始化时取得迁移锁。
2. 一个 DB 事务读取旧配置，创建一个确定记录的 UUID profile“默认配置”、migration journal 和目标 activeId；profile 标记 migrating，在完成前不对请求可用。没有旧配置且无旧 key 时可保持空列表，不生成虚假的已配置组。
3. 读取旧 key，若存在则写新 key并读回比对；读取失败保留 pending，不删除旧值。无旧 key 是合法 missing 状态。
4. DB 事务标记目标可用、global 值及迁移完成。非敏感旧连接字段此时可清理；旧 key 删除失败记录 cleanup_pending，不重复创建 profile，也不阻止已经可用的新组。
5. 重启按 journal 中同一 profileId 继续；新 key 已在而 DB 尚 pending 时核实后推进。仅在新配置已提交且新 key 核实后才能删除旧 key。

进程在每一步之后崩溃都不能造成无配置、重复 profile、丢 key 或误用另一组。迁移失败可用旧配置兼容读取界面显示与重试，但请求必须选择唯一已核实的凭证路径，不能同一请求悄悄在新旧 key 之间回退。

### 4.2 修改、复制和删除

密钥修改先记录 pending operation，再写入并核实，随后提交 profile revision；失败期间该组不可发新请求。进程重启按当前 secure-store 内容与操作阶段完成提交或显示需重输，不能谎称旧 key 已恢复。首期不承诺在 secret 写入成功后能回滚到已被覆盖的旧 key。

2026-11-12 恢复策略：pending writeSecret 无法证明已提交时清除不确定密钥并标记 interrupted，
保留配置字段、提示重新输入；清除结果须核实，失败保留 pending 供再次恢复。
deleteSecret/clearSecret 重做删除后完成，update 结束无密钥副作用的未完成日志。
credentialState 增加运行时 `interrupted`，同时传递给设置页；数据库结构与导出格式不变。

复制密钥遵循同样的 pending 流程，默认只复制非敏感字段。删除先在 DB 逻辑删除并更新 active/global，再删 secret，失败保留 tombstone+cleanup journal 重试；未完成清理明确显示，不从列表中消失就宣称凭证已删除。

## 5. 备份、恢复与数据清理

- 数据库备份包含非敏感 profile、全局 activeId 和历史快照，不含系统 secure-store 数据；恢复后显示“密钥需重新配置”。
- 恢复过程必须重建 credential namespace：将恢复的 profile 重新分配 UUID，更新 activeId 和运行期关联，保留历史快照的原 ID 作为历史标识；不能因为本机 secure storage 恰好同 UUID 还残留 key 就自动重新绑定。
- 历史 `ai_conversations.profile_id` 与 profile_snapshot 表示当时身份，不在恢复时批量改写；它们不要求外键指向当前可编辑配置，也不靠 join 当前配置恢复当时名称。
- 恢复时忽略备份中 pending secret journal，不重放其他机器的密钥操作；为当前机器创建本地恢复记录。
- 恢复前先收敛本进程在途请求，并把原本机待清理 credential ID 记录到不随数据库覆盖的本地恢复 journal（仅 ID/阶段、不含 secret）。恢复完成后按 journal 回收旧绑定；失败可重试，不能因覆盖数据库丢掉清理线索。
- 清除所有 AI 配置需遍历已知 profile 和 tombstone，清 secret 后再移除 cleanup 记录；不以 delete DB 行替代凭证清理。
- 删除书籍不删全局 profile；删除 profile 不删聊天、摘录或笔记。导出历史带 profile 的当时名称/provider/model，不带 endpoint 的敏感部分。

## 6. 在途请求与历史

点击发送/测试时原子捕获有效 profileId、revision、不可变 settings 与该组 credential。后续切换活动组仅影响新请求；当前流继续使用已捕获身份并在回答卡片显示当时模型。用户可取消，不默认重发到新组。

删除正在被请求使用的 profile 不改写已发送请求，发起删除时说明有在途请求；默认取消它并等待取消收敛后完成删除，无法撤回已到服务端的内容需按实际状态说明。绝不在删除后自动转发。

同一线程可在明确配置身份下续问，历史每轮保留自己的 profile snapshot；若选择换模型，界面提示将带哪些历史轮次，沿用现有上下文范围与预算，不偷加更多正文。

## 7. 错误、实施与验收

错误码：`profile_missing/profile_conflict/profile_incomplete/credential_missing/credential_unavailable/credential_migration_pending/credential_cleanup_pending/test_stale`。不含密钥的错误可重试；请求失败和配置保存失败分别显示。

实施：F3-A 模型/Drift/v9；F3-B journal、旧值迁移与 crash 测试；F3-C 分组 draft/CRUD/轻量选择器；F3-D AiChatService、历史/导出/恢复及安装。

| ID | 场景 | 必须结果 |
| --- | --- | --- |
| F3-01 | 两组不同 endpoint/key，轮流发送 | 每次只用对应组，不串密钥 |
| F3-02 | A 草稿切 B 再回 A，外部更新 A | 草稿保留，冲突可见，active 不隐式保存草稿 |
| F3-03 | 保存/测试期间编辑或换组 | 旧结果不覆盖新组，按钮互斥正确 |
| F3-04 | 旧配置有/无 key；迁移每步崩溃重启 | 恢复同一个 profile，key 不丢、不重复、不误用 |
| F3-05 | 系统密钥服务失败、删除 key 失败 | 与未配置区分；pending 可见且可恢复 |
| F3-06 | 复制配置，默认/显式复制 key | 只有显式路径复制 secret |
| F3-07 | 流式请求中切换/删除组 | 身份不漂移、不自动重发，历史模型正确 |
| F3-08 | 删除最后一组；备份后恢复到同机 | active/global 合法；恢复不自动取残留 key |
| F3-09 | 旧历史、未知 snapshot 版本、导出 | 旧身份不被当前组覆盖，秘密不出现 |

拟新增：`test/core/database/ai_profiles_migration_test.dart`、`test/features/settings/ai_profiles_controller_test.dart`、`test/core/security/ai_credential_service_test.dart`；扩展现有 `test/features/settings/ai_settings_form_controller_test.dart`、`test/features/ai/ai_chat_service_test.dart` 和导出/恢复测试。所有 secret 测试使用 fake，绝不修改用户真实凭证。
