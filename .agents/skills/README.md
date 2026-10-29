# Project skills

Agent skills for this repo. `.claude/skills` is a symlink to this folder, so Claude Code,
Codex and other Agent Skills clients read the same files.

Dictum's own skills: `dictum-review` (diff audit against `AGENTS.md` and `docs/`), `dictum-qa`
(manual QA checklist) and `release`. Everything else is vendored from upstream, unmodified, and picked
for this codebase (SwiftUI + AppKit menu bar app, Swift 6 language mode). Skills for testing,
iOS-only APIs and SwiftData were left out on purpose.

| Skill | Upstream | Commit | License |
| --- | --- | --- | --- |
| `swiftui-pro` | [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill) | `f2920b6` (2026-10-26) | MIT |
| `swiftui-expert-skill` | [AvdLee/SwiftUI-Agent-Skill](https://github.com/AvdLee/SwiftUI-Agent-Skill) | `204dba7` (2026-10-06) | MIT |
| `swift-concurrency-pro` | [twostraws/Swift-Concurrency-Agent-Skill](https://github.com/twostraws/Swift-Concurrency-Agent-Skill) | `bee3f69` (2026-05-17) | MIT |
| `swift-concurrency` | [AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill) | `d577081` (2026-09-14) | MIT |
| `swift-api-design-guidelines-skill` | [Erikote04/Swift-API-Design-Guidelines-Agent-Skill](https://github.com/Erikote04/Swift-API-Design-Guidelines-Agent-Skill) | `36cdc1b` (2026-02-18) | MIT |
| `appkit-interop`, `swiftui-patterns`, `view-refactor` | [openai/plugins](https://github.com/openai/plugins) `plugins/build-macos-apps/skills` | `0722921` (2026-10-08) | MIT (per `plugin.json`) |

To update a skill, re-copy its folder from upstream and bump the commit here. The nested
`skills/` copy and `plugin.json` in `swift-concurrency-pro` are Claude-plugin packaging and
are not vendored.
