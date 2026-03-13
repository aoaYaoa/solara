package middlewares

// 此文件用于导出所有中间件，方便导入使用

/*
可用中间件列表:

基础中间件:
|- Logger()          - 请求日志
|- Recovery()        - 错误恢复
|- CORS()            - 跨域支持
|- RequestID()       - 请求ID

安全中间件:
|- Security()        - 安全响应头
|- NoCache()         - 禁用缓存
|- ContentType()     - 内容类型检查
|- SignatureMiddleware()    - API 签名验证
|- OptionalSignatureMiddleware() - 可选签名验证
|- IPAccessMiddleware()      - IP访问控制（黑白名单）

加密中间件:
|- DecryptionMiddleware()    - 请求解密
|- EncryptionMiddleware()    - 响应加密

性能中间件:
|- Compression()     - 响应压缩
|- RateLimit()       - 请求限流

认证中间件:
|- AuthMiddleware()           - JWT 认证（必需）
|- OptionalAuth()             - 可选认证
|- RoleBasedAuth()           - 基于角色的认证

工具函数:
|- GetRequestID()    - 获取请求ID
|- GetTokenFromRequest() - 获取令牌
|- InitIPAccessConfig() - 初始化IP访问控制配置
*/

// 示例：在路由中使用所有中间件
/*
import "github.com/gin-gonic/gin"
import . "backend/internal/middlewares"

func setupRouter(r *gin.Engine) {
    // 全局中间件
    r.Use(
        RequestID(),          // 1. 生成请求ID
        Logger(),            // 2. 记录日志
        Recovery(),          // 3. 错误恢复
        CORS(),             // 4. 跨域支持
        Security(),          // 5. 安全头
        DecryptionMiddleware(), // 6. 请求解密
        SignatureMiddleware(), // 7. 签名验证
        EncryptionMiddleware(), // 8. 响应加密
        Compression(),       // 9. 响应压缩
        RateLimit(100, 200), // 10. 限流：100 req/s, burst 200
    )

    // 公开路由
    public := r.Group("/api/public")
    {
        public.GET("/health", healthHandler.Check)
    }

    // 需要认证的路由
    protected := r.Group("/api")
    protected.Use(AuthMiddleware())
    {
        protected.GET("/tasks", taskHandler.GetAllTasks)
        protected.POST("/tasks", taskHandler.CreateTask)
    }

    // 需要特定角色的路由
    admin := r.Group("/api/admin")
    admin.Use(RoleBasedAuth([]string{"admin"}))
    {
        admin.DELETE("/tasks/:id", taskHandler.DeleteTask)
    }
}
*/
