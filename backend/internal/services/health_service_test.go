package services

import (
	"context"
	"errors"
	"testing"
)

func TestHealthServiceReportsDegradedWhenDependencyDown(t *testing.T) {
	svc := NewHealthService(map[string]DependencyCheck{
		"database": {
			Enabled: true,
			Check: func(ctx context.Context) error {
				return nil
			},
		},
		"redis": {
			Enabled: true,
			Check: func(ctx context.Context) error {
				return errors.New("dial failed")
			},
		},
		"kafka": {
			Enabled: false,
		},
	})

	data := svc.CheckHealth(context.Background())
	status, _ := data["status"].(string)
	if status != "degraded" {
		t.Fatalf("expected status degraded, got %q", status)
	}

	components, _ := data["components"].(map[string]any)
	redis, _ := components["redis"].(map[string]any)
	if redis["status"] != "down" {
		t.Fatalf("expected redis down, got %v", redis["status"])
	}
}
