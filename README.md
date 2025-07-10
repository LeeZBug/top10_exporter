### top10_exporter
用于获取CPU或者内存占用前10的exporter, 程序监听在9090端口


#### 二次开发相关

windows环境下交叉编译linux可执行二进制文件
```
set GOOS=linux
set GOARCH=amd64
go build -o top10_exporter
```

#### TODO
- [x] 程序主体
- [ ] 命令行配置(监听端口等)
