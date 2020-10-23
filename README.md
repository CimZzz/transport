# Transport

旨在提供完整流程的代理体验，您可以通过本工具实现以下功能:

1. 远程代理端口 TCP 访问/监听
2. 远程代理端口 UDP 接收/发送

另外，您也可以通过使用库 Api 来构建自己的代理工具


## 原理

通常情况下，代理实现的逻辑是借助远程服务器，来实现连接到该服务器的连接进行相互通信:

```text
Machine A =====> Server
Machine B =====> Server
Machine A <=====> Server <=====> Machine B
```

我们把 `Machine A/B` 称为 `Client`，把 `Server` 称为 `Bridge`

每个连接到 Bridge 的 Client，在经历握手之后，都要向 Bridge 注册一个 `ClientId`，作为该 Client 在这个 Bridge 中的唯一标识

> 如果 Bridge 中已存在相同的 ClientId，那么视为本次 Client 连接 Bridge 失败