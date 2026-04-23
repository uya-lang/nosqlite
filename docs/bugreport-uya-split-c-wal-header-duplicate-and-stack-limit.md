# Bug Report: Uya split-C duplicates `wal_header.c` output and requires larger stack for integrated Phase 12 runner

日期：2026-04-23

## 状态

`已确认，待修复`

当前结论：

- 这不是 NoSQLite `Phase 12` 业务逻辑本身的正确性问题。
- 这是当前 Uya split-C 构建链上的老问题，在集成用例 [test_phase12_features.uya](/home/winger/nosqlite/nosqlite/test_phase12_features.uya) 上被稳定触发。
- 目前至少包含两类现象：
  - 生成物 `.uyacache/nosqlite/lib/storage/wal_header.c` 出现整段重复代码，导致 C 编译阶段 redefinition。
  - 手工修掉重复代码后，默认栈限制下运行 `.uyacache/a.out` 会 segfault；放大栈后可通过。

## 摘要

运行 `Phase 12` 集成用例时，当前 Uya split-C 路径会先在生成的 C 文件里重复展开 `wal_header` 相关定义，导致链接前的 C 编译失败。

把这部分生成物手工修补后，集成 runner 仍会在默认栈限制下崩溃；给更大的栈限制后，runner 可正常返回成功。

这说明当前至少存在：

1. 一个代码生成/依赖收集重复展开问题
2. 一个默认栈预算下的运行时/代码生成栈占用问题

## 影响范围

这会直接影响依赖 split-C 路径的集成验证：

- `Phase 12` 的源码和测试已经实现
- SQL parser 测试可以正常编译并运行
- 但集成 runner 在标准 split-C 构建路径上不能直接稳定通过

结果是：

- 我们必须临时修补 `.uyacache` 生成物
- 并且在运行前手动放大栈限制

这不适合作为正式 CI 或标准开发流程的一部分。

## 复现文件

当前最直接的复现文件：

- [test_phase12_features.uya](/home/winger/nosqlite/nosqlite/test_phase12_features.uya)

这是当前 `Phase 12` 的集成用例，覆盖：

- `CREATE INDEX`
- `IndexScan`
- `ORDER BY`
- `UPDATE`
- `DELETE`
- 重启后验证

## 复现命令

在仓库根目录执行：

```bash
rm -rf .uyacache
./uya/bin/uya nosqlite/test_phase12_features.uya
```

随后构建 split-C 产物：

```bash
make -C .uyacache UYA_OUT=a.out -j4
```

## 实际结果 1：生成的 `wal_header.c` 出现重复定义

当前生成物：

- [.uyacache/nosqlite/lib/storage/wal_header.c](/home/winger/nosqlite/.uyacache/nosqlite/lib/storage/wal_header.c)

可以观察到同一组 `wal_header_*` 定义出现两次。一个简单的检查方式：

```bash
rg -n "size_t wal_header_size\\(\\)" .uyacache/nosqlite/lib/storage/wal_header.c
```

实际会看到两处定义，例如：

- 第 24 行附近
- 第 162 行附近

随后 `cc` 会报出大量 `redefinition of ...`，典型包括：

- `WAL_HEADER_ENCODED_SIZE`
- `wal_header_size`
- `wal_header_encoded_size`
- `wal_header_encode`
- `wal_header_decode`
- `wal_header_checksum_valid`

## 预期结果 1

预期行为应该是：

- `wal_header.c` 只生成一份完整定义
- `make -C .uyacache UYA_OUT=a.out -j4` 能直接通过
- 不需要手工编辑 `.uyacache` 生成物

## 实际结果 2：默认栈限制下运行会 segfault

在手工修补 `wal_header.c` 重复段后，可以重新链接成功。

但如果直接运行：

```bash
./.uyacache/a.out
```

当前会在默认栈限制下崩溃，返回：

```text
rc=139
```

即 segmentation fault。

调试回溯显示崩溃出现在初始化阶段，典型栈回溯里可以看到：

- `primary_btree_init(...)`
- `db_test_init_at_stem(...)`
- `db_test_open_at_stem(...)`
- `db_test_create_at_stem(...)`

## 预期结果 2

预期行为应该是：

- 在默认 shell 栈限制下直接运行 `.uyacache/a.out`
- 集成 runner 正常结束
- 若逻辑有问题，应返回测试失败码，而不是栈相关 segfault

## 当前临时规避方案

当前可行但不可接受为正式流程的 workaround：

1. 手工修补生成物，删掉 `.uyacache/nosqlite/lib/storage/wal_header.c` 中第二段重复定义
2. 重新执行：

```bash
make -C .uyacache UYA_OUT=a.out -j4
```

3. 运行时放大栈限制：

```bash
ulimit -s 262144
./.uyacache/a.out
```

在这个 workaround 下，`Phase 12` 集成 runner 可以通过。

## 与业务逻辑的边界

当前已经验证：

- SQL parser 的 `Phase 12` 用例可正常编译和运行
- 在手工修补生成物并放大栈限制后，`Phase 12` 集成用例可返回成功

因此当前更像是：

- split-C 生成阶段的重复展开问题
- 加上较大局部数组/深调用链下的栈预算问题

而不是 `UPDATE/DELETE/CREATE INDEX/ORDER BY` 本身语义错误。

## 可能的排查方向

### 1. split-C 依赖收集 / 去重

重点检查：

- `lib/storage/wal_header.uya` 在 split-C 图里是否被当作两个逻辑模块重复展开
- `use lib.storage.wal_header` 与 `use lib.storage` 风格是否在当前实现里被视作不同入口
- 同一文件在 codegen emit 阶段是否被遍历两次

### 2. 生成 C 时的模块路径归一化

当前仓库里 `storage/*` 模块头注释长期使用：

```text
模块路径：lib/storage/*.uya → use lib.storage;
```

而调用方又广泛使用：

```text
use lib.storage.wal_header;
```

建议确认当前 codegen / module graph 是否在这个边界上有重复注册。

### 3. 栈占用估算与大局部数组

当前 `Phase 12` 路径里会经过一些较大的局部对象，例如：

- `PrimaryBTree`
- `CommitViewState` 复制链路
- `DocBlob` / JSON scratch

建议确认：

- codegen 是否对大结构体返回/复制产生了异常的栈放大
- 某些函数是否需要改成静态存储或堆分配
- 调试模式下默认栈是否明显小于当前生成代码的需要

## 建议回归标准

修复后，至少应保证下面两条命令在**不手工改 `.uyacache`、不调大栈限制**的前提下稳定通过：

```bash
rm -rf .uyacache
./uya/bin/uya nosqlite/test_phase12_features.uya
make -C .uyacache UYA_OUT=a.out -j4
./.uyacache/a.out
```

并且：

- `wal_header.c` 中不再出现重复函数/常量定义
- 集成 runner 返回 `0`

## 备注

如果后续要细分处理，建议拆成两个独立 issue：

1. `split-C duplicate emission for lib.storage.wal_header`
2. `default stack overflow / excessive stack usage on integrated runner`

但在当前使用体验上，它们是同一次 `Phase 12` 集成验证一起暴露出来的，因此先合并记录在这份 bug report 中。
