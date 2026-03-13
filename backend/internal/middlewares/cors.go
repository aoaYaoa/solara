package middlewares

import (
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"time"
)

// CORS CORS 中间件
func CORS(allowedOrigins []string) gin.HandlerFunc {
	wildcard := len(allowedOrigins) == 1 && allowedOrigins[0] == "*"
	cfg := cors.Config{
		AllowMethods:  []string{"GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"},
		AllowHeaders:  []string{"Origin", "Content-Type", "Authorization", "X-Requested-With", "X-Signature", "X-Timestamp"},
		ExposeHeaders: []string{"Content-Length"},
		MaxAge:        12 * time.Hour,
	}
	if wildcard {
		cfg.AllowAllOrigins = true
		cfg.AllowCredentials = false
	} else {
		cfg.AllowOrigins = allowedOrigins
		cfg.AllowCredentials = true
	}
	return cors.New(cfg)
}
