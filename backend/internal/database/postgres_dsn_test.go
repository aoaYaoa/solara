package database

import (
	"strings"
	"testing"
)

func TestBuildPostgresDSNRespectsSSLMode(t *testing.T) {
	cfg := &DatabaseConfig{
		Host:     "localhost",
		Port:     5432,
		Database: "postgres",
		Username: "postgres",
		Password: "pwd",
		SSLMode:  "require",
	}

	dsn := buildPostgresDSN(cfg)
	if !strings.Contains(dsn, "sslmode=require") {
		t.Fatalf("expected dsn to include sslmode=require, got: %s", dsn)
	}
}
