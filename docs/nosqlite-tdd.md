# NoSQLite TDD 执行说明

日期：2026-04-22

## 默认流程

所有模块默认遵循：

1. 先写失败测试
2. 再写最小实现
3. 最后重构并保持测试为绿

## 执行顺序

- 优先纯单元测试
- 再做 runtime smoke / 集成测试
- 最后补 golden / corruption / recovery

## 测试组织规则

- 可执行测试入口使用 `test_*.uya`
- 逻辑分组目录放在 `nosqlite/tests/`
- 当前因 Uya 项目根约束，测试入口暂放在 `nosqlite/` 根下

## 模块级要求

### core

- 新增类型/常量时，先补基础断言测试

### storage

- 页布局变更前，先补布局/边界/checksum 测试
- pager 读写变更前，先补 round-trip 测试
- Meta/WAL 兼容字段变更前，先补 codec/checksum 测试

### wal / recovery

- 任何格式变更都要先补 corruption / truncation / recovery 测试

## Done 条件

一个 TODO 子项只有在下面都成立时才能勾选：

- 对应测试文件或测试组已经存在
- 失败测试已先出现过
- 当前实现能稳定通过相关测试
- 文档或命名约定已同步更新
