# bearoster-share（日历订阅中转 Worker）

Bearoster「日历分享」功能的服务端：App 把生日日历的 iCalendar 文本 PUT 上来，
订阅者用 `https://bearoster.com/c/{readToken}` 订阅（Apple 日历 / Google 日历
均可）。KV 里只存 `{ secretHash, ics, updatedAt }`。

访问模型：

- **读**：URL 里的 `readToken`（128 bit 随机）就是唯一凭证，无法猜测。
- **写**：App 另持一个 32 字节 `writeSecret`（用户 Keychain 里），以
  `Authorization: Bearer` 头提交；Worker 只存它的 SHA-256。拿不到订阅链接
  也覆盖不了内容。
- 停用/重新生成链接时 App 会 DELETE 旧条目；`updatedAt` 仅作排查用途。

## 部署（人工执行，与 MAS pkg 同模式）

在已登录 wrangler 的终端里：

```bash
cd cloudflare/share-worker
npx wrangler kv namespace create SHARES     # 输出的 id 填进 wrangler.jsonc
npx wrangler deploy
```

部署后验证（逐条应得到注释里的结果）：

```bash
# 未知 token → 404
curl -s -o /dev/null -w "%{http_code}\n" https://bearoster.com/c/AAAAAAAAAAAAAAAAAAAAAA

# 写入（token 22+ 位 URL-safe 字符即可）
curl -s -o /dev/null -w "%{http_code}\n" -X PUT \
  -H "Authorization: Bearer test-secret" -H "X-Bearoster-App: bearoster-share-v1" \
  -H "Content-Type: text/calendar; charset=utf-8" \
  --data $'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n' \
  https://bearoster.com/c/TestTokenTestTokenTestT
# → 204

# 读取 → 200 且返回 ICS 文本
curl -s https://bearoster.com/c/TestTokenTestTokenTestT

# 错误密钥覆盖 → 403；不带 marker 匿名新建 → 403
# 删除 → 204，再 GET → 404
curl -s -o /dev/null -w "%{http_code}\n" -X DELETE \
  -H "Authorization: Bearer test-secret" \
  https://bearoster.com/c/TestTokenTestTokenTestT
```

## 运维注意

- **回滚**：`npx wrangler delete`（删 Worker）即可恢复纯静态站；KV 数据保留，
  彻底下线再 `npx wrangler kv namespace delete`。
- **KV 免费额度**：读 10 万次/天、写 1 千次/天。App 端有内容去重 + 3 秒防抖，
  正常用量远低于额度；如果出现异常写入，先在 Cloudflare 后台看该 Worker 的
  请求量，再考虑给 PUT 加速率限制。
- **隐私口径**：该服务托管用户联系人的姓名与生日（订阅必需字段），属数据
  收集——隐私政策页、ASC 营养标签需同步更新后才可随分享功能上架。
- StoreKit 商品 id：`com.bearoster.app.share.unlock`（non-consumable）。
