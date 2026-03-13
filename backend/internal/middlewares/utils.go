package middlewares

// min 返回两个整数中的较小值
// 用于中间件中的各种计算
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
