# Verilog 练习项目

本项目是一个数字 IC 设计练习项目，包含了四个核心计算模块 (`Add`, `Maxpool`, `Conv`, `Deconv`) 的 HLS模型与 RTL 实现。

**你的任务**：当前目录中的 RTL 与 HLS 代码均包含预设的 **Bug**。你需要通过仿真、调试和代码分析，修复这些错误，使所有模块的仿真结果通过 (`TEST PASSED`)。

## 操作说明 (How to Run)

### 1. 环境准备
在开始仿真前，请确保已安装相关的 EDA 工具 (如 VCS/Verdi) 和 Python 环境。
在 `rtl` 目录下，系统会自动调用 `set_env.sh` 设置环境变量。

运行过程中若报错：`fatal error: ap_int.h: No such file or directory`。
请打开 `hls/CMakeLists.txt` 将`include directories`里的路径改成HLS库的路径。
我们的服务器vivado一般安装2025.1和2020.2版本，路径分别是:
*   2025.1： `/tools/Xilinx/2025.1/Vitis/include`
*   2020.2： `/tools/Xilinx/Vitis_HLS/2020.2/include`

### 2. 生成测试数据
进入数据生成目录，运行脚本生成 Golden Data。
```bash
cd rtl/data
python3 gen_add.py      # 生成加法器数据
python3 gen_maxpool.py  # 生成池化数据
python3 gen_conv.py     # 生成卷积数据
python3 gen_deconv.py   # 生成反卷积数据
```

### 3. 运行 RTL 仿真
进入对应模块的测试目录运行仿真。
**以 Maxpool 为例**:
```bash
cd rtl/test/maxpool_2x2
make sim        # 编译并运行仿真
```
*   如果测试通过，终端将显示 `*** TEST PASSED ***`。
*   如果测试失败，请查看 `sim.log` 或启动波形调试。

### 4. 查看波形 (Verdi)
如果仿真失败，可以使用 Verdi 查看波形进行调试（需要图形化窗口）：
```bash
make verdi
```

### 5. 运行 HLS 仿真 (C++)
`hls` 目录包含对应的 C++ 算法实现，用于验证算法逻辑。
```bash
cd hls
mkdir -p build && cd build
cmake ..
make
./tb_maxpool    # 运行 Maxpool 的 C++ 测试
```

---

## 调试任务列表 (Debugging Tasks)

请按照以下顺序或建议进行调试。每个模块都考察了特定的数字电路设计知识点。

### 1. 加法器 (Add Module)
*   **文件路径**: `rtl/design/add.sv`
*   **考察知识点**:
    *   **AXI-Stream 握手协议**: 理解 `valid` (数据有效) 和 `ready` (下游反压) 信号的正确交互逻辑。
    *   **有符号/无符号数运算**: Verilog 中 `signed` 与 `unsigned` 的定义会对运算结果产生什么影响？
*   **任务**: 修复握手信号死锁问题，并确保数据精度正确。

### 2. 最大池化 (Maxpool Module) - **核心任务**
*   **文件路径**: `rtl/design/maxpool_2x2.sv`
*   **考察知识点**: 理解池化的原理和目的，完善缓冲 (Line Buffer) 的读写控制、二维数据流的计数器设计。
*   **设计要求**: 一拍最多只能做一次比较（max）操作，不能在同一拍内做两次或以上的 max 操作。
    *   **❌ 典型错误案例**:
        ```verilog
        // 错误示范：在同一拍内嵌套调用或多次调用 max
        assign row_max = max_vec(pixel_buf, in_data);
        assign out_data = max_vec(row_max, lb_rdata);
        ```
    *   **⚠️ 为什么这样写是错的？**
        在软件中这样写没问题，但在硬件综合时，上述代码会在**同一个时钟周期内实例化两个比较器**，这会增加组合逻辑延迟。正确的做法是利用在不同的时钟周期（如偶数列和奇数列）分别进行比较，通过状态调度复用同一个比较器资源。

*   **调试指南**: 请设计不同cntr_h和cntr_w下的时序，按照正确的逻辑对不同行/列计数器在对应的各个时钟周期内程序的行为进行分析和修正，并补全下表：

    |cycle|row=0，col=0|row=0，col=1|row=1，col=0|row=1，col=1|
    |---|---|---|---|---|
    |  0 | | | | |
    |  1 | | | | |
    |  …… | | | | |

### 3. 卷积 (Conv Module)
*   **文件路径**: `rtl/design/conv.sv`, `rtl/design/conv_mac.sv`
*   **考察知识点**:
    *   **死锁与握手**: 分析 AXI-Stream 握手信号 (`valid`/`ready`) 逻辑，排查导致流水线挂死的原因。
    *   **边界与顺序**: 检查多层循环计数器是否存在 Off-by-one 偏差，以及通道数据流顺序是否正常。
*   **任务**: 修复死锁问题，校准计数器边界，并恢复正确的数据通道顺序。

### 4. 反卷积 (Deconv Module)
*   **文件路径**: `rtl/design/deconv.sv`, `rtl/design/deconv_mac.sv`
*   **考察知识点**:
    *   **有符号数算术**: 深入理解 Verilog 中 `signed` 关键字对加法和乘法运算位宽扩展及符号位的影响。
    *   **时序与逻辑**: 检查 Line Buffer 读地址生成的准确性，以及 Valid 信号与数据流的同步关系。
*   **任务**: 修正有符号数运算错误，修复读写控制逻辑，确保输出无异常。


### 5. wrgen_req_merge

#### 模块作用
`wrgen_req_merge` (Write Request Generator - Merge) 的主要功能是将多个**地址连续**的小位宽写请求，**合并**为一个大位宽的写请求，以提高总线或下一级模块的传输效率。

类似于“拼车”：如果是去往同一个方向（地址连续）的乘客（数据），我们可以把他们塞进一辆大巴车（合并输出）一次运走；如果地址不连续，或者大巴车满了，就必须发车。

#### 关键参数
*   `MERGE_NUM`: 合并数量（比如 2，表示最多积攒 2 个请求就必须发送）。
*   `ADDR_STEP`: 地址步长（判断连续的依据）。

#### 接口列表
| 接口名 | 方向 | 描述 |
| :--- | :--- | :--- |
| `clk`, `rst_n` | input | 时钟与复位 |
| **Input Interface** | | |
| `in_vld` | input | 输入请求有效 |
| `in_rdy` | output | 模块准备好接收（反压信号） |
| `in_addr` | input | 输入地址 |
| `in_dat`, `in_msk` | input | 输入数据与掩码 |
| `in_lst` | input | 包尾标记（Last），表示当前笔数据是包的最后一笔，遇到它必须立即发车 |
| **Output Interface** | | |
| `out_vld` | output | 输出请求有效 |
| `out_rdy` | input | 下游准备好接收 |
| `out_addr` | output | 合并后的首地址 |
| `out_dat`, `out_msk` | output | 合并后的宽数据（宽度是输入的 `MERGE_NUM` 倍） |
| `out_lst` | output | 传递 Last 属性 |

---

### 你的任务：梳理逻辑并填写代码

不要急着写代码。

对于这种带有“缓存”、“合并”、“条件触发”功能的模块，直接写代码很容易漏掉 corner case（边界情况）。

我们需要维护一个核心状态：**当前缓存里攒了几个请求？** 我们用计数器 `cnt` 来表示。

请完成下表的填写。梳理清楚在不同场景下，硬件应该做什么。

#### 核心逻辑真值表 (思考题)

请根据**当前状态**（缓存了多少个）和**输入情况**（来了个什么样的数据），决定**输出行为**和**下个状态**。

**提示：**
*   **连续条件**：`current_addr == last_received_addr + ADDR_STEP`
*   **发车条件**：攒满了(`cnt == MERGE_NUM-1`) **或者** 地址断开了 **或者** 来了 Last 信号。

| 场景序号 | 当前 Count (`cnt`) | 输入有效 (`in_vld`) | 输入特征 (地址连续? Last?) | **动作 1: 是否发车?** (`out_vld`) | **动作 2: 如何更新 Count?** | **动作 3: 缓存行为** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | 0  | 0 | X |  | |  |
| **2** | 0 | 1 | 普通数据 (非 Last) | |  |  |
| **3** | 0  | 1 | **是 Last** ||| |
| **4** | > 0 且 < MAX | 1 | **地址连续** 且 非 Last || | |
| **5** | > 0 且 < MAX | 1 | **地址连续** 且 **是 Last** | |  |  |
| **6** | > 0 (任意非空) | 1 | **地址不连续** (断开) |  |  |  |
| **7** | = MAX (满) | 1 | **地址连续** | || |

#### 编码步骤指导

##### 第一步：定义内部信号
你需要定义寄存器来存储数据：
```systemverilog
logic [MERGE_NUM-1:0][DATA_WIDTH-1:0] data_buffer; // 数据缓存
logic [ADDR_WIDTH-1:0] last_addr_reg;              // 记录上一次的地址，用于比对连续性
logic [$clog2(MERGE_NUM)-1:0] cnt;                 // 计数器
// ... 其他需要的信号
```

##### 第二步：判断“连续”与“断开”
写一段组合逻辑，判断当前输入的 `in_addr` 和 `last_addr_reg` 是否连续。
```systemverilog
assign is_continuous = (in_addr == last_addr_reg + ADDR_STEP);
```

##### 第三步：实现计数器与发车逻辑 (核心)
参考上面的真值表，编写 `always_ff` 块来更新 `cnt` 和触发 `out_vld`。
这里是最容易出错的地方：**当发生“地址不连续”时，既要发送旧数据，又要接收新数据，这通常意味着你需要在一个周期内完成“Flush Old” + "Push New"。**

如果是简单的状态机，可能需要两个周期。但为了高性能，我们希望流水线不中断。
*   思考：如果下游 `out_rdy` 没准备好怎么办？
*   提示：`in_rdy` (反压) 逻辑需要仔细设计。如果 Buffer 满了且下游 `out_rdy` 为低，你需要拉低 `in_rdy` 阻止上游继续发数据。

##### 第四步：数据通路
根据 `cnt` 将输入数据 `in_dat` 写入 `data_buffer` 的对应位置。如果触发了 Flush (不连续)，记得把新的数据写入到 Buffer 的 **第 0 个** 位置，而不是 `cnt + 1` 的位置。

---
