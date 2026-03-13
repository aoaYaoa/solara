package logger

import (
	"io"
	"log"
	"os"
	"regexp"
)

var (
	InfoLogger  *log.Logger
	ErrorLogger *log.Logger
	DebugLogger *log.Logger
	WarnLogger  *log.Logger
)

// ANSI Color Codes
const (
	Reset   = "\033[0m"
	Red     = "\033[31m"
	Green   = "\033[32m"
	Yellow  = "\033[33m"
	Blue    = "\033[34m"
	Magenta = "\033[35m"
	Cyan    = "\033[36m"
)

// StripANSIWriter 用于去除 ANSI 颜色代码的 Writer
type StripANSIWriter struct {
	w  io.Writer
	re *regexp.Regexp
}

func NewStripANSIWriter(w io.Writer) *StripANSIWriter {
	return &StripANSIWriter{
		w:  w,
		re: regexp.MustCompile(`\x1b\[[0-9;]*m`),
	}
}

func (w *StripANSIWriter) Write(p []byte) (n int, err error) {
	// 去除 ANSI 代码
	clean := w.re.ReplaceAll(p, []byte(""))
	return w.w.Write(clean)
}

func Init() {
	// 创建按天轮转的日志写入器
	// 日志将保存在 ./logs 目录下，文件名为 app-YYYY-MM-DD.log
	dailyWriter := NewDailyWriter("logs", "app")

	// 文件输出器（去除颜色代码）
	fileWriter := NewStripANSIWriter(dailyWriter)

	// 组合写入器：同时输出到控制台和文件
	// Info/Debug/Warn -> 标准输出 + 文件
	// 控制台保留颜色，文件去除颜色
	outWriter := io.MultiWriter(os.Stdout, fileWriter)

	// Error -> 标准错误 + 文件
	errWriter := io.MultiWriter(os.Stderr, fileWriter)

	// 使用带颜色的前缀初始化 Logger
	// Info: 绿色
	InfoLogger = log.New(outWriter, Green+"[INFO] "+Reset, log.Ldate|log.Ltime|log.Lshortfile)
	// Error: 红色
	ErrorLogger = log.New(errWriter, Red+"[ERROR] "+Reset, log.Ldate|log.Ltime|log.Lshortfile)
	// Debug: 青色
	DebugLogger = log.New(outWriter, Cyan+"[DEBUG] "+Reset, log.Ldate|log.Ltime|log.Lshortfile)
	// Warn: 黄色
	WarnLogger = log.New(outWriter, Yellow+"[WARN] "+Reset, log.Ldate|log.Ltime|log.Lshortfile)
}

func Info(v ...any) {
	InfoLogger.Println(v...)
}

func Error(v ...any) {
	ErrorLogger.Println(v...)
}

func Debug(v ...any) {
	DebugLogger.Println(v...)
}

func Warn(v ...any) {
	WarnLogger.Println(v...)
}

func Infof(format string, v ...any) {
	InfoLogger.Printf(format, v...)
}

func Errorf(format string, v ...any) {
	ErrorLogger.Printf(format, v...)
}

func Debugf(format string, v ...any) {
	DebugLogger.Printf(format, v...)
}

func Warnf(format string, v ...any) {
	WarnLogger.Printf(format, v...)
}
