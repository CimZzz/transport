# Transport

Transport 迎来全面改变，移除旧版 BridgeServer 和 HttpServer，使用新结构重新设计了一套基于出网口匹配的代理模式.

该模式下，分为三种连接类型:

1. RequestServer: 请求代理端，监听源设备上的端口，通过访问该端口实现代理的目的
2. ResponseSocket: 响应代理端，作为代理目的端，最终代理的请求会经由该端实际发出
3. BridgeServer: 桥服务器端，用来连接和匹配 RequestServer 和 ResponseSocket，来实现代理的目的

> 后续会开发更多自定义属性，实现更高级的代理模式