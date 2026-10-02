package buildkit

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunTemplateTests(t *testing.T) {
	root := t.TempDir()
	scripts := filepath.Join(root, "scripts")
	if err := os.MkdirAll(scripts, 0o755); err != nil {
		t.Fatal(err)
	}
	testProgram, err := os.ReadFile(filepath.Join(repoRoot(t), "internal", "buildkit", "testdata", "template-test-pass.sh"))
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(scripts, "test.sh"), testProgram, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "compose.yaml"), []byte("services: {}\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	if code := RunTemplateTests([]string{"--root", root}, &stdout, &stderr); code != 0 {
		t.Fatalf("code=%d stderr=%s", code, stderr.String())
	}
	if !strings.Contains(stdout.String(), "PASS") {
		t.Fatalf("output=%s", stdout.String())
	}
}

func TestVerifyTemplateImagePinsRejectsDrift(t *testing.T) {
	roots := []string{filepath.Join(t.TempDir(), "one"), filepath.Join(t.TempDir(), "two")}
	for index, root := range roots {
		if err := os.MkdirAll(root, 0o755); err != nil {
			t.Fatal(err)
		}
		digest := strings.Repeat(string(rune('a'+index)), 64)
		contents := "services:\n  app:\n    image: lehighlts/base:1@sha256:" + digest + "\n"
		if err := os.WriteFile(filepath.Join(root, "compose.yaml"), []byte(contents), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := verifyTemplateImagePins(roots); err == nil {
		t.Fatal("digest drift was accepted")
	}
}

func TestVerifyTemplateImagePinsAcceptsLegacyComposeFilename(t *testing.T) {
	root := t.TempDir()
	contents := "services:\n  app:\n    image: lehighlts/base:1@sha256:" + strings.Repeat("a", 64) + "\n"
	if err := os.WriteFile(filepath.Join(root, "docker-compose.yml"), []byte(contents), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := verifyTemplateImagePins([]string{root}); err != nil {
		t.Fatalf("legacy Compose filename rejected: %v", err)
	}
}
