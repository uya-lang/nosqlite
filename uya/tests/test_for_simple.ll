; ModuleID = 'tests/programs/test_for_simple.uya'
source_filename = "tests/programs/test_for_simple.uya"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

define i32 @main() {
entry:
  %arr = alloca [3 x i32], align 4
  %0 = alloca [3 x i32], align 4
  %1 = getelementptr [3 x i32], ptr %0, i32 0, i32 0
  store i32 1, ptr %1, align 4
  %2 = getelementptr [3 x i32], ptr %0, i32 0, i32 1
  store i32 2, ptr %2, align 4
  %3 = getelementptr [3 x i32], ptr %0, i32 0, i32 2
  store i32 3, ptr %3, align 4
  %4 = load [3 x i32], ptr %0, align 4
  store [3 x i32] %4, ptr %arr, align 4
  %sum = alloca i32, align 4
  store i32 0, ptr %sum, align 4
  br label %for.init.0

for.init.0:                                       ; preds = %entry
  %5 = alloca i32, align 4
  store i32 0, ptr %5, align 4
  %arr1 = load [3 x i32], ptr %arr, align 4
  %6 = alloca [3 x i32], align 4
  store [3 x i32] %arr1, ptr %6, align 4
  br label %for.cond.0

for.cond.0:                                       ; preds = %for.inc.0, %for.init.0
  %7 = load i32, ptr %5, align 4
  %8 = icmp slt i32 %7, 3
  br i1 %8, label %for.body.0, label %for.end.0

for.body.0:                                       ; preds = %for.cond.0
  %9 = load i32, ptr %5, align 4
  %10 = getelementptr [3 x i32], ptr %6, i32 0, i32 %9
  %11 = load i32, ptr %10, align 4
  %12 = alloca i32, align 4
  store i32 %11, ptr %12, align 4
  %sum2 = load i32, ptr %sum, align 4
  %item = load i32, ptr %12, align 4
  %13 = add i32 %sum2, %item
  store i32 %13, ptr %sum, align 4
  br label %for.inc.0

for.inc.0:                                        ; preds = %for.body.0
  %14 = load i32, ptr %5, align 4
  %15 = add i32 %14, 1
  store i32 %15, ptr %5, align 4
  br label %for.cond.0

for.end.0:                                        ; preds = %for.cond.0
  %sum3 = load i32, ptr %sum, align 4
  %16 = icmp ne i32 %sum3, 6
  br i1 %16, label %if.then.1, label %if.end.1

if.then.1:                                        ; preds = %for.end.0
  ret i32 1

if.end.1:                                         ; preds = %for.end.0
  ret i32 0
}
