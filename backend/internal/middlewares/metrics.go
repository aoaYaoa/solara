package middlewares

import (
	"fmt"
	"net/http"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type requestMetricKey struct {
	Method string
	Path   string
	Status string
}

type durationMetricKey struct {
	Method string
	Path   string
}

type metricsCollector struct {
	mu sync.RWMutex

	requestTotal  map[requestMetricKey]uint64
	durationCount map[durationMetricKey]uint64
	durationSum   map[durationMetricKey]float64
	inflight      int64
	startedAt     time.Time
}

var collector = newMetricsCollector()

func newMetricsCollector() *metricsCollector {
	return &metricsCollector{
		requestTotal:  make(map[requestMetricKey]uint64),
		durationCount: make(map[durationMetricKey]uint64),
		durationSum:   make(map[durationMetricKey]float64),
		startedAt:     time.Now().UTC(),
	}
}

// ResetMetrics 仅用于测试重置指标状态。
func ResetMetrics() {
	collector = newMetricsCollector()
}

// Metrics 请求指标中间件。
func Metrics() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		collector.incInflight()
		defer collector.decInflight()

		c.Next()

		path := c.FullPath()
		if path == "" {
			path = c.Request.URL.Path
		}

		method := c.Request.Method
		status := strconv.Itoa(c.Writer.Status())
		durationSeconds := time.Since(start).Seconds()

		collector.observe(method, path, status, durationSeconds)
	}
}

// MetricsHandler 暴露 Prometheus 文本格式指标。
func MetricsHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Data(http.StatusOK, "text/plain; version=0.0.4; charset=utf-8", []byte(ExportMetricsText()))
	}
}

// ExportMetricsText 导出 Prometheus 文本格式指标。
func ExportMetricsText() string {
	return collector.exportText()
}

func (m *metricsCollector) incInflight() {
	m.mu.Lock()
	m.inflight++
	m.mu.Unlock()
}

func (m *metricsCollector) decInflight() {
	m.mu.Lock()
	m.inflight--
	m.mu.Unlock()
}

func (m *metricsCollector) observe(method, path, status string, durationSeconds float64) {
	reqKey := requestMetricKey{Method: method, Path: path, Status: status}
	durKey := durationMetricKey{Method: method, Path: path}

	m.mu.Lock()
	m.requestTotal[reqKey]++
	m.durationCount[durKey]++
	m.durationSum[durKey] += durationSeconds
	m.mu.Unlock()
}

func (m *metricsCollector) exportText() string {
	m.mu.RLock()
	defer m.mu.RUnlock()

	var b strings.Builder
	b.WriteString("# HELP http_requests_total Total number of HTTP requests.\n")
	b.WriteString("# TYPE http_requests_total counter\n")

	reqKeys := make([]requestMetricKey, 0, len(m.requestTotal))
	for k := range m.requestTotal {
		reqKeys = append(reqKeys, k)
	}
	sort.Slice(reqKeys, func(i, j int) bool {
		if reqKeys[i].Method != reqKeys[j].Method {
			return reqKeys[i].Method < reqKeys[j].Method
		}
		if reqKeys[i].Path != reqKeys[j].Path {
			return reqKeys[i].Path < reqKeys[j].Path
		}
		return reqKeys[i].Status < reqKeys[j].Status
	})
	for _, k := range reqKeys {
		b.WriteString(fmt.Sprintf(
			"http_requests_total{method=\"%s\",path=\"%s\",status=\"%s\"} %d\n",
			escapeLabelValue(k.Method), escapeLabelValue(k.Path), escapeLabelValue(k.Status), m.requestTotal[k],
		))
	}

	b.WriteString("# HELP http_request_duration_seconds Request duration in seconds.\n")
	b.WriteString("# TYPE http_request_duration_seconds summary\n")

	durKeys := make([]durationMetricKey, 0, len(m.durationSum))
	for k := range m.durationSum {
		durKeys = append(durKeys, k)
	}
	sort.Slice(durKeys, func(i, j int) bool {
		if durKeys[i].Method != durKeys[j].Method {
			return durKeys[i].Method < durKeys[j].Method
		}
		return durKeys[i].Path < durKeys[j].Path
	})
	for _, k := range durKeys {
		sum := m.durationSum[k]
		count := m.durationCount[k]
		b.WriteString(fmt.Sprintf(
			"http_request_duration_seconds_sum{method=\"%s\",path=\"%s\"} %.6f\n",
			escapeLabelValue(k.Method), escapeLabelValue(k.Path), sum,
		))
		b.WriteString(fmt.Sprintf(
			"http_request_duration_seconds_count{method=\"%s\",path=\"%s\"} %d\n",
			escapeLabelValue(k.Method), escapeLabelValue(k.Path), count,
		))
	}

	b.WriteString("# HELP http_inflight_requests Current in-flight HTTP requests.\n")
	b.WriteString("# TYPE http_inflight_requests gauge\n")
	b.WriteString(fmt.Sprintf("http_inflight_requests %d\n", m.inflight))

	var mem runtime.MemStats
	runtime.ReadMemStats(&mem)

	b.WriteString("# HELP go_goroutines Number of goroutines.\n")
	b.WriteString("# TYPE go_goroutines gauge\n")
	b.WriteString(fmt.Sprintf("go_goroutines %d\n", runtime.NumGoroutine()))

	b.WriteString("# HELP go_memstats_alloc_bytes Number of bytes allocated and still in use.\n")
	b.WriteString("# TYPE go_memstats_alloc_bytes gauge\n")
	b.WriteString(fmt.Sprintf("go_memstats_alloc_bytes %d\n", mem.Alloc))

	b.WriteString("# HELP go_memstats_heap_inuse_bytes Number of heap bytes in use.\n")
	b.WriteString("# TYPE go_memstats_heap_inuse_bytes gauge\n")
	b.WriteString(fmt.Sprintf("go_memstats_heap_inuse_bytes %d\n", mem.HeapInuse))

	uptime := time.Since(m.startedAt).Seconds()
	if uptime < 0 {
		uptime = 0
	}
	b.WriteString("# HELP process_uptime_seconds Process uptime in seconds.\n")
	b.WriteString("# TYPE process_uptime_seconds gauge\n")
	b.WriteString(fmt.Sprintf("process_uptime_seconds %.0f\n", uptime))

	return b.String()
}

func escapeLabelValue(v string) string {
	v = strings.ReplaceAll(v, "\\", "\\\\")
	v = strings.ReplaceAll(v, "\"", "\\\"")
	v = strings.ReplaceAll(v, "\n", "\\n")
	return v
}
