package jwt

import (
	"backend/pkg/utils/logger"
	"testing"
	"time"
)

func TestSetDefaultSecretRejectsWeakSecret(t *testing.T) {
	logger.Init()

	if err := SetDefaultSecret("short-secret"); err == nil {
		t.Fatalf("expected weak secret to be rejected")
	}
}

func TestGenerateTokenUsesConfiguredDefaultSecret(t *testing.T) {
	logger.Init()

	secret := "secret-A-very-strong-secret-1234567890"
	if err := SetDefaultSecret(secret); err != nil {
		t.Fatalf("SetDefaultSecret returned error: %v", err)
	}
	if err := SetDefaultSecret("secret-B-very-strong-secret-0987654321"); err != nil {
		t.Fatalf("SetDefaultSecret returned error: %v", err)
	}
	t.Cleanup(func() {
		_ = SetDefaultSecret(secret)
	})

	token, err := GenerateToken("u-1", "alice", "admin", "", time.Minute)
	if err != nil {
		t.Fatalf("GenerateToken returned error: %v", err)
	}

	if _, err := ValidateToken(token, ""); err != nil {
		t.Fatalf("ValidateToken with configured secret should succeed, got: %v", err)
	}

	if _, err := ValidateToken(token, "wrong-secret-very-strong-secret-000"); err == nil {
		t.Fatalf("ValidateToken with wrong secret should fail")
	}
}
