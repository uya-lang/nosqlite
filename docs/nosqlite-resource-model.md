# NoSQLite 资源模型

日期：2026-04-22

## 目标

NoSQLite 的核心资源模型固定为三类：

- owning type
- borrow type
- guard type

这三类不是文档口号，而是后续 API 设计的硬约束。

## 三类定义

### 1. owning type

拥有底层资源的唯一所有权。

特征：

- 默认负责资源生命周期
- 应优先定义 `drop`
- 不应被随意复制

典型对象：

- `DbHandle`
- `Txn`
- `QueryCursor`
- `QueryResult`

### 2. borrow type

只借用已有对象，不拥有底层资源。

特征：

- 生命周期必须短于被借用对象
- 只读 borrow 可别名
- 可变 borrow 不可别名

典型对象：

- `RowRef`
- `DocBlobView`
- 各类 page/header 只读视图

### 3. guard type

表示“已持有某个需要显式释放的状态”。

特征：

- 构造成功即代表资源已被持有
- 退出作用域时应自动释放
- 本质上是拥有型资源对象，但语义上强调状态持有

典型对象：

- `WriterLockGuard`
- `PagePin`
- 后续的 `CommitViewPin`

## 当前骨架约定

当前仓库已用基础模型常量固定下面的判断：

- owning: `requires_drop = true`, `aliasable = false`
- borrow(read-only): `requires_drop = false`, `aliasable = true`
- borrow(mutable): `requires_drop = false`, `aliasable = false`
- guard: `requires_drop = true`, `aliasable = false`

## 后续落地规则

- 先定义 guard/owning 类型，再写依赖它们的路径
- 不允许先铺裸布尔状态位，再事后回补 guard 语义
- 任何 lock/pin/view lease 一旦进入可逃逸 API，都必须优先 guard 化
