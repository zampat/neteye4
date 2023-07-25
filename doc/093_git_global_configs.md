# Configuration for github

## Proxy configuration

When comunication needs to occur via proxy confiure according to https://stackoverflow.com/questions/24907140/git-returns-http-error-407-from-proxy-after-connect

Config samples:
```
git config --global http.proxy=http://<user>:<password>@<proxy host ip>:<proxy host port>
git config --global http.proxyAuthMethod 'basic'
```

Verify configurations
```
# git config  --list
```
