# Chatbox 社区版（Community Edition）

[chatboxai/chatbox](https://github.com/chatboxai/chatbox) 的隐私保护、去商业化分支——一个运行于 Windows、macOS 和 Linux 的桌面 AI 客户端，完全使用你自己的模型服务。

与上游相同，以 GNU GPL v3 许可证分发。

## 为什么有这个分支

上游 Chatbox 是一个优秀的本地优先客户端，但带有商业层：遥测、账号/许可证体系、订阅引导、云增值服务与服务器驱动的营销界面。社区版将这一切剥离，同时保留客户端以你自己的 API Key 完整可用。

**已确保移除：**

| 领域 | 移除内容 |
| --- | --- |
| 遥测 | Sentry、Google Analytics（含设备 ID 的 Measurement Protocol）、Plausible |
| 账号 | Chatbox AI 登录、许可证密钥、套餐/配额追踪、Token 存储 |
| 商业化 | 升级提示、免费套餐领取引导、扩展包、赞助组件、资助链接 |
| 云增值 | 内置 Chatbox AI 搜索、云端文档解析、订阅制 MCP 服务器、远程模型目录、远程配置、后台技能同步 |
| 服务器驱动 UI | 营销弹窗、客户端通知、云端托管的引导会话 |
| 首次启动 | 预置演示对话（你的会话列表从空白开始） |
| 分发 | 官方自动更新源、S3/R2 发布目标、反盗版域名守卫 |

**保留可用：**

- 多供应商对话：OpenAI、Anthropic、Gemini、DeepSeek、Groq、OpenRouter、Ollama、LM Studio 及任何 OpenAI 兼容端点
- 通过你自己的供应商进行图片生成
- MCP 服务器（自带）、技能市场（基于 GitHub）、Agent 模式
- 知识库与会话 RAG，使用你自己的 embedding/rerank 模型
- 网页搜索：Bing、Tavily、Bocha、Querit 或自托管 SearXNG
- 本地优先存储：对话存于 IndexedDB/SQLite，知识库为本地 SQLite 文件，设置存于本地配置——任何内容都不会被同步

## 快速开始

### 安装

从本分支的 GitHub Releases 页面下载安装包，或从源码构建（见下文）。构建未签名；Windows 上会出现 SmartScreen 提示——选择"更多信息" → "仍要运行"。

### 配置模型

1. 打开 **设置 → 模型提供商**
2. 为任意供应商添加 API Key（或指向本地 Ollama / LM Studio）
3. 开始对话

没有账号步骤，也不需要登录任何服务。

## 验证

上述隐私承诺是可强制执行、可测试的，而不只是文档声明：

```bash
# 校验/重放全部 52 项社区版门控（幂等）
./build-scripts/sanitize.sh           # macOS / Linux
pwsh ./build-scripts/sanitize.ps1     # Windows

# 证明运行中的构建没有上游/遥测流量
pnpm start:cdp                                   # 带调试端口的开发构建
node build-scripts/cdp-network-probe.mjs 45 9333 # 预期 external=0 denied=0
node build-scripts/cdp-ui-assert.mjs 9333        # 预期 UI 无 SaaS 入口
```

全部净化以小门控实现，集中于 `src/shared/ce-edition.ts` 的五个开关，源码中以 `[Chatbox CE]` 标记。

## 从源码构建

要求：Node.js >= 22.13，pnpm >= 10.17。

```bash
pnpm install
pnpm dev             # 开发模式
pnpm run package     # 为当前平台打包（未签名）
pnpm test:unit       # 单元测试
```

打包基于 electron-builder：已移除上游 S3 发布目标，Windows 签名为 no-op 钩子；产物输出至 `release/build/`。

## 持续集成

`.github/workflows/` 提供三条流水线：

- **build.yml** — push/PR/手动触发：净化门禁 → 安装依赖 → 为运行平台打包 → 上传产物（Windows NSIS、macOS dmg、Linux AppImage/deb）
- **sync-upstream.yml** — 每日定时：合并上游 main、重放净化器、守卫发布配置、类型检查，通过后打预发布 tag 并构建预发布产物（合并冲突或门控丢失会显式失败，等待人工处理）
- **release.yml** — 推送 `ce-v*` tag 触发：verify-only 净化校验 + 类型检查，随后三平台完整构建并发布为正式 GitHub Release

## 跟进上游

```bash
git fetch origin
git checkout main && git merge --ff-only origin/main
git checkout feature/community-edition && git merge main
./build-scripts/sanitize.sh     # 重新校验门控；有 FAIL 就重新补上
pnpm exec tsc --noEmit && pnpm test:unit
```

净化器是安全网：上游合并若覆盖了某个门控，脚本（和 CI）都会发现。

## 仓库结构

```
src/
  main/       Electron 主进程
  preload/    preload 桥接
  renderer/   React 界面（路由、组件、状态）
  shared/     共享逻辑、类型、供应商定义、CE 开关
packages/
  chatbox-core/   与框架无关的领域层
  chatbox-react/  共享 React hooks/stores
  chatbox-i18n/   翻译
build-scripts/    净化器 + CDP 验证探针
.github/workflows 构建、同步、发布流水线
```

## 许可证

[GPL-3.0](./LICENSE)

基于 Bin Huang 及贡献者的 [Chatbox](https://github.com/chatboxai/chatbox)。本分支与上游项目及其服务不存在任何隶属、背书或商业关系。
