package main

import (
    "log"
    "net/http"
    "strconv"
    "time"

    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
    "github.com/shirou/gopsutil/v3/process"
)

var (
    // 定义指标
    processMemoryUsage = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "top_process_memory_usage_bytes",
            Help: "Memory usage of processes in bytes",
        },
        []string{"pid", "name"},
    )

    processCPUUsage = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "top_process_cpu_usage_percent",
            Help: "CPU usage of processes in percentage",
        },
        []string{"pid", "name"},
    )
)

func init() {
    // 注册指标
    prometheus.MustRegister(processMemoryUsage)
    prometheus.MustRegister(processCPUUsage)
}

// getTopMemoryProcesses 获取内存使用率最高的前 10 个进程
func getTopMemoryProcesses() ([]*process.Process, error) {
    processes, err := process.Processes()
    if err != nil {
        return nil, err
    }

    processInfo := make([]struct {
        proc *process.Process
        mem  uint64
    }, 0)

    for _, p := range processes {
        memInfo, err := p.MemoryInfo()
        if err != nil {
            continue
        }

        processInfo = append(processInfo, struct {
            proc *process.Process
            mem  uint64
        }{p, memInfo.RSS})
    }

    // 按内存使用率排序
    topProcesses := make([]*process.Process, 0)
    for i := 0; i < len(processInfo) && i < 10; i++ {
        maxIndex := i
        for j := i + 1; j < len(processInfo); j++ {
            if processInfo[j].mem > processInfo[maxIndex].mem {
                maxIndex = j
            }
        }
        processInfo[i], processInfo[maxIndex] = processInfo[maxIndex], processInfo[i]
        topProcesses = append(topProcesses, processInfo[i].proc)
    }

    return topProcesses, nil
}

// getTopCPUProcesses 获取 CPU 使用率最高的前 10 个进程
func getTopCPUProcesses() ([]*process.Process, error) {
    processes, err := process.Processes()
    if err != nil {
        return nil, err
    }

    processInfo := make([]struct {
        proc *process.Process
        cpu  float64
    }, 0)

    for _, p := range processes {
        cpuPercent, err := p.CPUPercent()
        if err != nil {
            continue
        }

        processInfo = append(processInfo, struct {
            proc *process.Process
            cpu  float64
        }{p, cpuPercent})
    }

    // 按 CPU 使用率排序
    topProcesses := make([]*process.Process, 0)
    for i := 0; i < len(processInfo) && i < 10; i++ {
        maxIndex := i
        for j := i + 1; j < len(processInfo); j++ {
            if processInfo[j].cpu > processInfo[maxIndex].cpu {
                maxIndex = j
            }
        }
        processInfo[i], processInfo[maxIndex] = processInfo[maxIndex], processInfo[i]
        topProcesses = append(topProcesses, processInfo[i].proc)
    }

    return topProcesses, nil
}

// 修改 collectMetrics 函数来使用新的函数
func collectMetrics() {
    for {
        // 获取内存使用率最高的进程
        memProcesses, err := getTopMemoryProcesses()
        if err != nil {
            log.Printf("Error getting top memory processes: %v", err)
            continue
        }

        // 获取 CPU 使用率最高的进程
        cpuProcesses, err := getTopCPUProcesses()
        if err != nil {
            log.Printf("Error getting top CPU processes: %v", err)
            continue
        }

        // 清除旧的指标
        processMemoryUsage.Reset()
        processCPUUsage.Reset()

        // 设置内存指标
        for _, p := range memProcesses {
            memInfo, err := p.MemoryInfo()
            if err != nil {
                continue
            }

            name, err := p.Name()
            if err != nil {
                name = "unknown"
            }

            pidStr := strconv.Itoa(int(p.Pid))
            processMemoryUsage.WithLabelValues(pidStr, name).Set(float64(memInfo.RSS))
        }

        // 设置 CPU 指标
        for _, p := range cpuProcesses {
            cpuPercent, err := p.CPUPercent()
            if err != nil {
                continue
            }

            name, err := p.Name()
            if err != nil {
                name = "unknown"
            }

            pidStr := strconv.Itoa(int(p.Pid))
            processCPUUsage.WithLabelValues(pidStr, name).Set(cpuPercent)
        }

        time.Sleep(10 * time.Second)
    }
}

func main() {
    log.Println("Starting process_exporter...This exporter display 'top10' processes(cpu and memory).")
    log.Println("Metrics will be available at http://*:8000/metrics")
    // 启动 HTTP 服务
    go func() {
        http.Handle("/metrics", promhttp.Handler())
        log.Fatal(http.ListenAndServe(":9090", nil))
    }()

    // 收集指标
    collectMetrics()