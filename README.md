# 城市分层统计工具

用于统计 Excel 或 CSV 文件中“归属地”列的城市分层数量和占比。

程序会从类似 `重庆-重庆-九龙坡` 的归属地字段中提取中间的城市名，再和 `city_tiers.yaml` 中定义的城市分层进行匹配，最终输出新一线、一线、二线、三线、四线和其他城市的数量及占比。

## 输入文件要求

支持的文件格式：

```text
.xlsx
.csv
```

文件中默认需要有一列：

```text
归属地
```

示例：

```text
归属地
重庆-重庆-九龙坡
广东-深圳市-南山
浙江-杭州市-西湖
新疆-喀什-喀什市
未知-未知-未知
```

程序会把这些值解析成：

```text
重庆-重庆-九龙坡 -> 重庆
广东-深圳市-南山 -> 深圳市
浙江-杭州市-西湖 -> 杭州市
新疆-喀什-喀什市 -> 喀什
```

匹配时会自动处理常见城市名差异，例如：

```text
重庆市 -> 重庆
深圳市 -> 深圳
喀什地区 -> 喀什
```

## 基本用法

如果已经安装成命令行工具：

```bash
city-tier-stats data.xlsx
```

如果在源码目录中运行：

```bash
poetry run ./city_tier_stats.py data.xlsx
```

CSV 文件也可以：

```bash
city-tier-stats data.csv
```

## 输出结果

默认只输出汇总结果：

```text
总数: 5
新一线: 2, 40.00%
一线: 1, 20.00%
二线: 0, 0.00%
三线: 0, 0.00%
四线: 1, 20.00%
其他: 1, 20.00%
```

统计口径是按记录统计，不去重。

也就是说，如果输入文件中有三行都属于重庆，会计算为三条新一线记录。

## 指定归属地列名

如果文件中的列名不是 `归属地`，可以用 `--column` 指定：

```bash
city-tier-stats data.xlsx --column 城市归属地
```

## 导出逐行明细

默认不会导出明细文件。如果需要查看每一行匹配到了哪个城市和分层，可以使用 `--detail-output`：

```bash
city-tier-stats data.xlsx --detail-output detail.csv
```

也可以导出为 Excel：

```bash
city-tier-stats data.xlsx --detail-output detail.xlsx
```

明细文件包含：

```text
归属地
城市
城市归一化
分层代码
分层
```

示例：

```text
归属地,城市,城市归一化,分层代码,分层
重庆-重庆-九龙坡,重庆,重庆,new_first,新一线
广东-深圳市-南山,深圳市,深圳,first,一线
未知-未知-未知,未知,未知,other,其他
```

## 自定义城市分层配置

默认会自动查找 `city_tiers.yaml`。

可以用 `-c` 或 `--config` 指定自定义配置：

```bash
city-tier-stats data.xlsx -c custom_city_tiers.yaml
```

配置文件格式：

```yaml
tiers:
  first:
    - 北京市
    - 上海市
    - 广州市
    - 深圳市

  new_first:
    - 成都市
    - 杭州市
    - 重庆市

  second: []
  third: []
  fourth: []
```

不需要配置 `other`。没有匹配到任何分层的城市会自动归为“其他”。

配置文件中的分层代码必须是：

```text
new_first
first
second
third
fourth
```

程序会检查同一个城市是否出现在多个分层中。如果重复出现在多个分层，会报错。

## 默认配置查找顺序

不传 `-c` 时，程序会自动查找默认配置：

```text
1. 当前运行目录下的 city_tiers.yaml
2. 程序所在目录下的 city_tiers.yaml
3. 脚本所在目录下的 city_tiers.yaml
4. 打包进程序内的 city_tiers.yaml
```

## 常见报错

### 文件中没有找到列

```text
文件中没有找到列：归属地
```

说明输入文件里没有 `归属地` 这一列。可以检查表头，或者使用：

```bash
city-tier-stats data.xlsx --column 实际列名
```

### 不支持的文件类型

```text
不支持的文件类型：.xls
```

当前只支持：

```text
.xlsx
.csv
```

老式 `.xls` 暂不支持。

### 找不到城市分层配置文件

```text
找不到城市分层配置文件：custom_city_tiers.yaml
```

说明 `-c` 指定的配置文件路径不存在。