## 1.0.0

- Initial version, provide transport server:
    
    1. ProxyServer
    2. TransportServer
    3. TransportBridge
    
## 1.0.1

- export classes.....

## 1.0.2

- export console_log_interface

## 1.0.3

- allow proxy server select cache...

## 1.0.4

- refactor all... provide transport server as follows:

    1. HttpProxyServer
    2. ProxyServer
    3. BridgeClientServer
    4. BridgeServer
    
- Bridge Server can use RSA crypt at hand-shake step.

## 1.0.5

- export HttpProxyServer

## 1.0.6

- allow bridge client specify peer address & port
- allow bridge client refuse response.
- fix intranet not access problem

## 1.0.7

- 重新设计 BridgeServer，移除旧版所有代理服务器