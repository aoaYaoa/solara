package middlewares

import "testing"

func TestSetEncryptionKeyRejectsInvalidLength(t *testing.T) {
	if err := SetEncryptionKey("short"); err == nil {
		t.Fatalf("expected invalid key length error")
	}
}

func TestSetEncryptionKeyAcceptsValidLength(t *testing.T) {
	if err := SetEncryptionKey("1234567890123456"); err != nil {
		t.Fatalf("expected valid key to pass, got: %v", err)
	}
}
