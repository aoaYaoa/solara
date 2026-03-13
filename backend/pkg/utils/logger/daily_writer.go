package logger

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// DailyWriter 实现按天轮转的日志写入器
type DailyWriter struct {
	Dir      string     // 日志目录
	Filename string     // 日志文件前缀
	file     *os.File   // 当前打开的文件
	lastDate string     // 当前文件的日期
	mu       sync.Mutex // 互斥锁，确保线程安全
}

// NewDailyWriter 创建一个新的 DailyWriter
func NewDailyWriter(dir, filename string) *DailyWriter {
	return &DailyWriter{
		Dir:      dir,
		Filename: filename,
	}
}

// Write 实现 io.Writer 接口
func (w *DailyWriter) Write(p []byte) (n int, err error) {
	w.mu.Lock()
	defer w.mu.Unlock()

	// 获取当前日期
	today := time.Now().Format("2006-01-02")

	// 如果日期变更或文件未打开，进行轮转
	if today != w.lastDate || w.file == nil {
		if err := w.rotate(today); err != nil {
			return 0, err
		}
	}

	return w.file.Write(p)
}

// rotate 轮转日志文件
func (w *DailyWriter) rotate(date string) error {
	// 关闭旧文件
	if w.file != nil {
		w.file.Close()
	}

	// 确保目录存在
	if err := os.MkdirAll(w.Dir, 0755); err != nil {
		return err
	}

	// 生成新文件名: logs/app-2023-10-27.log
	filename := filepath.Join(w.Dir, fmt.Sprintf("%s-%s.log", w.Filename, date))

	// 打开新文件 (追加模式)
	f, err := os.OpenFile(filename, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return err
	}

	w.file = f
	w.lastDate = date
	return nil
}
