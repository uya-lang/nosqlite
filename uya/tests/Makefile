# Uya 测试 Makefile（默认并行，PARALLEL_JOBS=8）
# 在项目根目录: make -C tests <目标> 或 make tests-uya
#
# 用法:
#   make test-uya         # 测试自举编译器（并行）
#   make test-uya-e       # 只显示错误
#   PARALLEL_JOBS=4 make test-uya   # 指定并行数

.PHONY: test-uya test-uya-e run-multifile-uya run-cross-deps-uya clean

# 配置
COMPILER_UYA = ../bin/uya
BUILD_DIR = build
TEST_DIR = .
PARALLEL_JOBS ?= 8

# 收集测试文件
TEST_FILES = $(wildcard $(TEST_DIR)/*.uya)
MULTIFILE_TESTS = $(wildcard $(TEST_DIR)/multifile/*.uya)
CROSS_DEPS_TESTS = $(wildcard $(TEST_DIR)/cross_deps/*.uya)
RESULT_DIR = $(BUILD_DIR)/results

test-uya:
	@echo "=========================================="
	@echo "测试自举编译器 (uya)（并行 $(PARALLEL_JOBS) 任务）"
	@echo "=========================================="
	@$(MAKE) -j$(PARALLEL_JOBS) run-test-uya

test-uya-e:
	@$(MAKE) test-uya 2>&1 | grep -E "FAIL|失败" || echo "✓ 所有测试通过"

$(BUILD_DIR) $(RESULT_DIR):
	@mkdir -p $@

define run_test_uya
@mkdir -p $(BUILD_DIR) $(RESULT_DIR)
@output_file="$(BUILD_DIR)/$(notdir $(basename $1)).c"; \
result_file="$(RESULT_DIR)/$(notdir $(basename $1)).result"; \
compiler_output=$$($(COMPILER_UYA) --c99 --nostdlib "$1" -o "$$output_file" 2>&1); \
compiler_exit=$$?; \
base_name="$(notdir $(basename $1))"; \
case "$$base_name" in error_*) is_expected=1;; *) is_expected=0;; esac; \
if [ $$compiler_exit -ne 0 ]; then \
    if [ $$is_expected -eq 1 ]; then echo "PASS: $$base_name (预期失败)"; echo PASS > "$$result_file"; \
    else echo "FAIL: $$base_name (退出码:$$compiler_exit)"; echo FAIL > "$$result_file"; fi; \
elif [ $$is_expected -eq 1 ]; then echo "FAIL: $$base_name (应失败但通过了)"; echo FAIL > "$$result_file"; \
elif [ ! -f "$$output_file" ]; then echo "FAIL: $$base_name (未生成输出)"; echo FAIL > "$$result_file"; \
else \
    link_ok=0; \
    extra_c_file=""; \
    has_main=0; grep -q "int main(" "$$output_file" 2>/dev/null && has_main=1 || grep -q "int32_t main(" "$$output_file" 2>/dev/null && has_main=1 || true; \
    if [ "$$base_name" = "extern_function" ]; then \
        extra_c_file="$(TEST_DIR)/extern_function_impl.c"; \
    elif [ "$$base_name" = "test_comprehensive_cast" ] || [ "$$base_name" = "test_ffi_cast" ] || [ "$$base_name" = "test_pointer_cast" ] || [ "$$base_name" = "test_simple_cast" ] || [ "$$base_name" = "test_extern_union" ]; then \
        extra_c_file="external_functions.c"; \
    elif [ "$$base_name" = "test_abi_calling_convention" ]; then \
        extra_c_file="$(TEST_DIR)/test_abi_helpers.c"; \
    elif [ "$$base_name" = "test_tflm_cmsis" ]; then \
        extra_c_file="$(TEST_DIR)/tflm_cmsis_host_stub.c"; \
    fi; \
    CC=gcc ./link_cimports_posix.sh "$$output_file" "$(BUILD_DIR)/$$base_name" "$$extra_c_file" >/dev/null 2>&1 && link_ok=1; \
    if [ $$link_ok -eq 1 ]; then \
        if "$(BUILD_DIR)/$$base_name" >/dev/null 2>&1; then echo "PASS: $$base_name"; echo PASS > "$$result_file"; \
        else echo "FAIL: $$base_name (运行失败)"; echo FAIL > "$$result_file"; fi; \
    else echo "FAIL: $$base_name (链接失败)"; echo FAIL > "$$result_file"; fi; \
fi
endef

TEST_UYA_TARGETS = $(addprefix test-uya-,$(notdir $(basename $(TEST_FILES))))

$(addprefix test-uya-,$(notdir $(basename $(TEST_FILES)))): test-uya-%: $(TEST_DIR)/%.uya
	$(call run_test_uya,$<)

run-multifile-uya: $(MULTIFILE_TESTS)
	@[ -n '$(MULTIFILE_TESTS)' ] || { echo "跳过 multifile"; exit 0; }; \
	mkdir -p $(BUILD_DIR)/multifile $(RESULT_DIR); \
	out_c="$(BUILD_DIR)/multifile/multifile.c"; out_exe="$(BUILD_DIR)/multifile/multifile"; \
	$(COMPILER_UYA) --c99 --nostdlib $(MULTIFILE_TESTS) -o "$$out_c" 2>/dev/null; ex=$$?; \
	if [ $$ex -ne 0 ]; then echo "FAIL: multifile (编译失败 $$ex)"; echo FAIL > "$(RESULT_DIR)/multifile.result"; exit 1; fi; \
	if [ ! -f "$$out_c" ]; then echo "FAIL: multifile (未生成输出)"; echo FAIL > "$(RESULT_DIR)/multifile.result"; exit 1; fi; \
	gcc --std=c99 -no-pie "$$out_c" -o "$$out_exe" 2>/dev/null || { echo "FAIL: multifile (链接失败)"; echo FAIL > "$(RESULT_DIR)/multifile.result"; exit 1; }; \
	"$$out_exe" >/dev/null 2>&1; ex=$$?; \
	if [ $$ex -eq 0 ]; then echo "PASS: multifile"; echo PASS > "$(RESULT_DIR)/multifile.result"; else echo "FAIL: multifile (运行退出 $$ex)"; echo FAIL > "$(RESULT_DIR)/multifile.result"; exit 1; fi

run-cross-deps-uya: $(CROSS_DEPS_TESTS)
	@[ -n '$(CROSS_DEPS_TESTS)' ] || { echo "跳过 cross_deps"; exit 0; }; \
	mkdir -p $(BUILD_DIR)/cross_deps $(RESULT_DIR); \
	out_c="$(BUILD_DIR)/cross_deps/cross_deps.c"; out_exe="$(BUILD_DIR)/cross_deps/cross_deps"; \
	$(COMPILER_UYA) --c99 --nostdlib $(CROSS_DEPS_TESTS) -o "$$out_c" 2>/dev/null; ex=$$?; \
	if [ $$ex -ne 0 ]; then echo "FAIL: cross_deps (编译失败 $$ex)"; echo FAIL > "$(RESULT_DIR)/cross_deps.result"; exit 1; fi; \
	if [ ! -f "$$out_c" ]; then echo "FAIL: cross_deps (未生成输出)"; echo FAIL > "$(RESULT_DIR)/cross_deps.result"; exit 1; fi; \
	gcc --std=c99 -no-pie "$$out_c" -o "$$out_exe" 2>/dev/null || { echo "FAIL: cross_deps (链接失败)"; echo FAIL > "$(RESULT_DIR)/cross_deps.result"; exit 1; }; \
	"$$out_exe" >/dev/null 2>&1; ex=$$?; \
	if [ $$ex -eq 0 ]; then echo "PASS: cross_deps"; echo PASS > "$(RESULT_DIR)/cross_deps.result"; else echo "FAIL: cross_deps (运行退出 $$ex)"; echo FAIL > "$(RESULT_DIR)/cross_deps.result"; exit 1; fi

run-test-uya: $(TEST_UYA_TARGETS) run-multifile-uya run-cross-deps-uya
	@pass=0; fail=0; expfail=0; \
	for f in $(RESULT_DIR)/*.result; do \
		[ -f "$$f" ] || continue; \
		if [ "$$(cat "$$f")" = "PASS" ]; then \
			pass=$$((pass+1)); \
			base=$$(basename "$$f" .result); [ "$${base#error_}" != "$$base" ] && expfail=$$((expfail+1)); \
		else fail=$$((fail+1)); fi; \
	done; \
	total=$$((pass+fail)); \
	echo ""; \
	echo "================================"; \
	echo "总计: $$total  通过: $$pass (含预期失败 $$expfail 项)  失败: $$fail"; \
	echo "================================"; \
	echo "✓ 测试完成"

clean:
	rm -rf $(BUILD_DIR)
