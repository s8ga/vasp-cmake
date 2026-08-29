# Find 模块增强路线图

对**我们自己的** find 模块(`FindELPA/FindLibXC/FindLibBEEF/FindTensorFlow/FindDL_MG/FindPSPFFT`)的增强计划。
上游领土(`FindDFTD4/FindSDFTD3/FindLIBMBD/FindFFTW/FindSCALAPACK/FindQD/FindWANNIER90`、
`sources_and_flags_options.cmake`)零接触,保持 behind=0。

## 全局约束

- **上下文安全红线**:验证脚本绝不把 VASP 源码内容带进输出 —— 断言全部在
  `tools/verify_config.sh` 内部完成,只回显 `PASS/FAIL + 布尔/计数`;验证只做到
  configure + generate,不跑编译阶段(编译错误会引用源码行)。
- **GPL 红线**:借鉴 cp2k 的模式但全部自研实现,不复制其代码(包括源自 Octopus 的宏)。
- **spack 兼容硬门槛**:`ELPA_ROOT/LIBBEEF_ROOT/LibXC_ROOT/TENSORFLOW_ROOT/CPPFLOW_ROOT`、
  选项名、target 名、`VASP_DFTD4_API` 语义不变;spack `package.py` 零改动。
- 节奏:每 Phase 本地 commit → `tools/verify_config.sh` 全绿 → 真实 spack 构建(用户执行)
  → 用户确认 → push(浮动引用,一次推一个 Phase)。

## Phase 0 — 回归防护网 ✅(2026-08-29)

- [x] `tools/verify_config.sh`:6 场景 configure-only 回归门
  (默认 / spack 全选项模拟 / DFTD4 V3 / V4 / 手动 fallback / ELPA pkg-config),
      内部断言只输出结论行;首跑写基线(`/tmp/vasp_verify_baseline/`),重跑比对漂移。
      环境要求:可用的 spack 前缀 + 系统pkg-config;本机系统 MPI 损坏,脚本自动用 spack openmpi。
- [x] 场景要点:spack 模拟需把**全部传递依赖前缀**放进 `CMAKE_PREFIX_PATH`
      (dftd4/s-dftd3 → mctc-lib → toml-f/jonquil、multicharge),且 s-dftd3 必须是
      cmake 构建的(1.2.1;1.4.0 那份没装 config 包)—— 与 spack 的
      `build_system=cmake` 依赖约束一致。

## Phase A — 统一探测基础设施 ✅(2026-08-29)

- [x] A1 `vasp_find_utils.cmake`:
  - `vasp_pkg_root(<out> <NAME> <PkgName> [EXTRA_VARS ...])`:
    cache `<NAME>_ROOT` → `ENV{<NAME>_ROOT}` → `<PkgName>_ROOT`(大小写变体,cache+env)
    → `ENV{<NAME>HOME}` → `ENV{EB<NAME>ROOT}`(EasyBuild)→ `ENV{CRAY_<NAME>_PREFIX_DIR}`;
    不做 `/usr` 回退。
  - `vasp_report(<PKG> <msg>)`:统一 STATUS 消息 + 一次性 cache 标志。
- [x] A2 FindELPA 换用(pkg-config 的 PKG_CONFIG_PATH 注入/还原保留)
- [x] A3 FindLibBEEF 换用 + 修 :16-17 重复 `set(_LIBBEEF_PATHS)`
- [x] A4 FindDL_MG / FindPSPFFT 换用 + 修两处同款重复 set
- [x] A5 FindTensorFlow 换用(Python site-packages glob 提示保留)
- [x] A6 FindLibXC 换用(4 个大小写变体名)
- [x] A7 验证:回归门全绿;`EBELPAROOT` 环境变量冒烟;无手写 ROOT 循环残留

## Phase B — ELPA 强化 ✅(2026-08-29)

- [x] B1 root:`VASP_ELPA_MIN_VERSION`(默认 2021.05.001)+ 版本化 `find_package(ELPA ...)`
- [x] B2 pkg-config 路径用 `elpa[_openmp]>=${ELPA_FIND_VERSION}` spec;FAIL_MESSAGE 人话
- [x] B3 try_compile 探针(`use elpa` 迷你程序;`ELPA_SKIP_PROBE` 开关;拦截老版本与
      跨编译器 .mod 不匹配)
- [x] B4 `VASP_OPENMP=ON` + 只找到串行 elpa → WARNING
- [x] B5 手动 fallback 在 ScaLAPACK target 存在时补进 `ELPA::ELPA`
- [x] B6 状态消息带版本与 openmp 信息
- [x] B7 负面测试:假老版本 `.pc`;假模块目录触发探针
- [x] B8 提交(检测强化 + 探针两个 commit)

## Phase C — 小补强 ✅(2026-08-29)

- [x] C1 FindLibXC:读 `xc_version.h` 拼版本串;`LibXC_FIND_VERSION` 下限校验;消息带版本
- [x] C2 root:680 修复:LibXC::libxc 是 INTERFACE target 无 `IMPORTED_LOCATION`,
      改为遍历 `LibXC_LIBRARIES/LibXC_FORTRAN_LIBRARIES` 收集 RPATH 目录
- [x] C3 CMakeLists_vaspml:TF 版本检查(`version_macros.h` 的 `TF_VERSION_STRING`,WARNING 级)
- [x] C4 回归门全绿 + 提交

## 不做的事

- BLAS/LAPACK/ScaLAPACK vendor 抽象(上游领土)
- GPU ELPA 变体探测(VASP 源码侧决定)
- 向上游发 PR
- 复制 GPL 代码
