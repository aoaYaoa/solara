package captcha

import (
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"io"
	"math/rand"
	"time"

	"golang.org/x/image/font"
	"golang.org/x/image/font/basicfont"
	"golang.org/x/image/math/fixed"
)

const (
	// 验证码字符集（排除易混淆字符）
	chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	// 验证码长度
	codeLength = 4
	// 图片宽度
	imageWidth = 120
	// 图片高度
	imageHeight = 40
)

// GenerateCode 生成随机验证码
func GenerateCode() string {
	rand.Seed(time.Now().UnixNano())
	code := make([]byte, codeLength)
	for i := 0; i < codeLength; i++ {
		code[i] = chars[rand.Intn(len(chars))]
	}
	return string(code)
}

// GenerateImage 生成验证码图片
func GenerateImage(code string, w io.Writer) error {
	// 创建图片
	img := image.NewRGBA(image.Rect(0, 0, imageWidth, imageHeight))

	// 填充背景色
	bgColor := color.RGBA{240, 240, 240, 255}
	draw.Draw(img, img.Bounds(), &image.Uniform{bgColor}, image.Point{}, draw.Src)

	// 绘制干扰线
	rand.Seed(time.Now().UnixNano())
	for i := 0; i < 3; i++ {
		x1 := rand.Intn(imageWidth)
		y1 := rand.Intn(imageHeight)
		x2 := rand.Intn(imageWidth)
		y2 := rand.Intn(imageHeight)
		lineColor := color.RGBA{
			uint8(rand.Intn(100)),
			uint8(rand.Intn(100)),
			uint8(rand.Intn(100)),
			100,
		}
		drawLine(img, x1, y1, x2, y2, lineColor)
	}

	// 绘制干扰点
	for i := 0; i < 30; i++ {
		x := rand.Intn(imageWidth)
		y := rand.Intn(imageHeight)
		dotColor := color.RGBA{
			uint8(rand.Intn(255)),
			uint8(rand.Intn(255)),
			uint8(rand.Intn(255)),
			128,
		}
		img.Set(x, y, dotColor)
	}

	// 绘制验证码文字
	for i, char := range code {
		x := 15 + i*25
		y := 25
		charColor := color.RGBA{
			uint8(rand.Intn(100)),
			uint8(rand.Intn(100)),
			uint8(rand.Intn(100)),
			255,
		}
		drawChar(img, x, y, string(char), charColor)
	}

	// 编码为 PNG
	return png.Encode(w, img)
}

// drawLine 绘制直线
func drawLine(img *image.RGBA, x1, y1, x2, y2 int, col color.Color) {
	dx := abs(x2 - x1)
	dy := abs(y2 - y1)
	sx, sy := 1, 1
	if x1 >= x2 {
		sx = -1
	}
	if y1 >= y2 {
		sy = -1
	}
	err := dx - dy

	for {
		img.Set(x1, y1, col)
		if x1 == x2 && y1 == y2 {
			break
		}
		e2 := err * 2
		if e2 > -dy {
			err -= dy
			x1 += sx
		}
		if e2 < dx {
			err += dx
			y1 += sy
		}
	}
}

// drawChar 绘制字符
func drawChar(img *image.RGBA, x, y int, char string, col color.Color) {
	point := fixed.Point26_6{
		X: fixed.Int26_6(x * 64),
		Y: fixed.Int26_6(y * 64),
	}

	d := &font.Drawer{
		Dst:  img,
		Src:  image.NewUniform(col),
		Face: basicfont.Face7x13,
		Dot:  point,
	}
	d.DrawString(char)
}

// abs 返回绝对值
func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
