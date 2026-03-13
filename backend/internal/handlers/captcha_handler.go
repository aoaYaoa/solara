package handlers

import (
	"backend/pkg/utils/captcha"
	"backend/pkg/utils/logger"
	"backend/pkg/utils/response"
	"bytes"
	"encoding/base64"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// CaptchaHandler 验证码处理器接口
type CaptchaHandler interface {
	GetCaptcha(c *gin.Context)
}

type captchaHandler struct{}

// NewCaptchaHandler 创建验证码处理器实例
func NewCaptchaHandler() CaptchaHandler {
	return &captchaHandler{}
}

// GetCaptcha 获取验证码
// @Summary 获取验证码
// @Description 生成验证码图片
// @Tags 认证
// @Produce json
// @Success 200 {object} response.Response{data=map[string]string}
// @Router /api/auth/captcha [get]
func (h *captchaHandler) GetCaptcha(c *gin.Context) {
	// 生成验证码（5分钟有效期）
	id, code := captcha.GenerateCaptcha(5 * time.Minute)

	// 生成验证码图片
	var buf bytes.Buffer
	if err := captcha.GenerateImage(code, &buf); err != nil {
		logger.Errorf("[CaptchaHandler] 生成验证码图片失败: %v", err)
		response.Error(c, "生成验证码失败", http.StatusInternalServerError)
		return
	}

	// 将图片转换为 Base64
	base64Image := base64.StdEncoding.EncodeToString(buf.Bytes())

	// 返回验证码 ID 和 Base64 图片
	response.SuccessWithData(c, "获取成功", gin.H{
		"captcha_id":    id,
		"captcha_image": "data:image/png;base64," + base64Image,
	})
}
