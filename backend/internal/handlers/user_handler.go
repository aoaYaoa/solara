package handlers

import (
	"backend/internal/dto"
	"backend/internal/services"
	"backend/pkg/utils/captcha"
	"backend/pkg/utils/logger"
	"backend/pkg/utils/response"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type UserHandler interface {
	Register(c *gin.Context)
	Login(c *gin.Context)
	AppLogin(c *gin.Context)
	GetProfile(c *gin.Context)
	ListUsers(c *gin.Context)
}

type userHandler struct {
	userService services.UserService
}

// NewUserHandler 创建用户处理器实例
func NewUserHandler(userService services.UserService) UserHandler {
	return &userHandler{
		userService: userService,
	}
}

// Register 用户注册
// @Summary 用户注册
// @Description 注册新用户
// @Tags 用户
// @Accept json
// @Produce json
// @Param request body dto.RegisterRequest true "注册信息"
// @Success 200 {object} response.Response{data=dto.RegisterResponse}
// @Router /api/auth/register [post]
func (h *userHandler) Register(c *gin.Context) {
	var req dto.RegisterRequest

	// 绑定请求数据
	if err := c.ShouldBindJSON(&req); err != nil {
		logger.Warnf("[UserHandler] 注册请求参数错误: %v", err)
		response.Error(c, "请求参数错误", http.StatusBadRequest)
		return
	}

	// 调用服务层
	user, err := h.userService.Register(c.Request.Context(), &req)
	if err != nil {
		logger.Warnf("[UserHandler] 注册失败: %v", err)
		response.Error(c, err.Error(), http.StatusBadRequest)
		return
	}

	// 返回成功响应
	response.SuccessWithData(c, "注册成功", user)
}

// Login 用户登录
// @Summary 用户登录
// @Description 用户登录获取 Token
// @Tags 用户
// @Accept json
// @Produce json
// @Param request body dto.LoginRequest true "登录信息"
// @Success 200 {object} response.Response{data=dto.LoginResponse}
// @Router /api/auth/login [post]
func (h *userHandler) Login(c *gin.Context) {
	var req dto.LoginRequest

	// 绑定请求数据
	if err := c.ShouldBindJSON(&req); err != nil {
		logger.Warnf("[UserHandler] 登录请求参数错误: %v", err)
		response.Error(c, "请求参数错误", http.StatusBadRequest)
		return
	}

	// 验证验证码（不区分大小写）
	if !captcha.VerifyCaptcha(req.CaptchaID, strings.ToUpper(req.CaptchaCode)) {
		logger.Warnf("[UserHandler] 验证码错误: captcha_id=%s, input=%s", req.CaptchaID, req.CaptchaCode)
		response.Error(c, "验证码错误或已过期", http.StatusBadRequest)
		return
	}

	// 调用服务层
	result, err := h.userService.Login(c.Request.Context(), &req)
	if err != nil {
		logger.Warnf("[UserHandler] 登录失败: %v", err)
		response.Error(c, err.Error(), http.StatusUnauthorized)
		return
	}

	// 返回成功响应
	response.SuccessWithData(c, "登录成功", result)
}

func (h *userHandler) AppLogin(c *gin.Context) {
	var req struct {
		Username string `json:"username" binding:"required"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, "请求参数错误", http.StatusBadRequest)
		return
	}
	result, err := h.userService.Login(c.Request.Context(), &dto.LoginRequest{
		Username: req.Username,
		Password: req.Password,
	})
	if err != nil {
		response.Error(c, err.Error(), http.StatusUnauthorized)
		return
	}
	response.SuccessWithData(c, "登录成功", result)
}

// GetProfile 获取当前用户信息
// @Summary 获取用户信息
// @Description 获取当前登录用户的信息
// @Tags 用户
// @Produce json
// @Security Bearer
// @Success 200 {object} response.Response{data=dto.UserResponse}
// @Router /api/user/profile [get]
func (h *userHandler) GetProfile(c *gin.Context) {
	// 从 Context 中获取用户 ID (UUID string)
	userID, exists := c.Get("user_id")
	if !exists {
		response.Error(c, "未认证", http.StatusUnauthorized)
		return
	}

	// 类型断言为 string
	uidStr, ok := userID.(string)
	if !ok {
		response.Error(c, "用户信息错误", http.StatusInternalServerError)
		return
	}

	// 解析 UUID
	uid, err := uuid.Parse(uidStr)
	if err != nil {
		response.Error(c, "用户ID格式错误", http.StatusBadRequest)
		return
	}

	// 获取用户信息
	user, err := h.userService.GetByID(c.Request.Context(), uid)
	if err != nil {
		logger.Warnf("[UserHandler] 获取用户信息失败: %v", err)
		response.Error(c, "用户不存在", http.StatusNotFound)
		return
	}

	// 返回用户信息（移除密码）
	response.SuccessWithData(c, "获取成功", dto.ToUserResponse(user))
}

// ListUsers 列出所有用户（管理员功能）
// @Summary 列出用户
// @Description 列出所有用户（需要管理员权限）
// @Tags 用户
// @Produce json
// @Security Bearer
// @Success 200 {object} response.Response{data=[]dto.UserResponse}
// @Router /api/admin/users [get]
func (h *userHandler) ListUsers(c *gin.Context) {
	// 检查管理员权限（从 Context 中获取）
	role, exists := c.Get("role")
	if !exists {
		response.Error(c, "未认证", http.StatusUnauthorized)
		return
	}

	userRole, ok := role.(string)
	if !ok || userRole != "admin" {
		response.Error(c, "权限不足", http.StatusForbidden)
		return
	}

	// 列出所有用户
	users, err := h.userService.List(c.Request.Context())
	if err != nil {
		logger.Errorf("[UserHandler] 列出用户失败: %v", err)
		response.Error(c, "获取用户列表失败", http.StatusInternalServerError)
		return
	}

	response.SuccessWithData(c, "获取成功", dto.ToUserResponseList(users))
}
