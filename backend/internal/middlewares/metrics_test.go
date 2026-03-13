package middlewares

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestMetricsMiddlewareRecordsRequest(t *testing.T) {
	ResetMetrics()
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(Metrics())
	r.GET("/ping", func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})

	req := httptest.NewRequest(http.MethodGet, "/ping", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Fatalf("expected status %d, got %d", http.StatusNoContent, w.Code)
	}

	body := ExportMetricsText()
	if !strings.Contains(body, `http_requests_total{method="GET",path="/ping",status="204"} 1`) {
		t.Fatalf("expected request counter in metrics output, got:\n%s", body)
	}
}

func TestMetricsEndpoint(t *testing.T) {
	ResetMetrics()
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(Metrics())
	r.GET("/metrics", MetricsHandler())

	req := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, w.Code)
	}
	if ct := w.Header().Get("Content-Type"); !strings.Contains(ct, "text/plain") {
		t.Fatalf("expected text/plain content type, got %q", ct)
	}
	if !strings.Contains(w.Body.String(), "# HELP http_requests_total") {
		t.Fatalf("expected metrics help text, got:\n%s", w.Body.String())
	}
	if !strings.Contains(w.Body.String(), "# HELP go_goroutines") {
		t.Fatalf("expected runtime metrics, got:\n%s", w.Body.String())
	}
	if !strings.Contains(w.Body.String(), "# HELP process_uptime_seconds") {
		t.Fatalf("expected uptime metrics, got:\n%s", w.Body.String())
	}
}
