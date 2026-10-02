package buildkit

import (
	"os/exec"
	"path/filepath"
	"testing"
)

func TestImportedImagesFollowDependencyPlan(t *testing.T) {
	metadata, err := LoadMetadata(repoRoot(t))
	if err != nil {
		t.Fatal(err)
	}
	for _, image := range []string{"actions-runner", "python3-13", "python3-14", "scyllaridae-cleanpdf", "scyllaridae-coverpage", "scyllaridae-hls", "scyllaridae-libreoffice", "scyllaridae-ocrpdf", "scyllaridae-openai-htr", "scyllaridae-pandoc", "scyllaridae-tn-warc", "scyllaridae-tn-zip", "scyllaridae-whisper"} {
		if !metadata.KnownImage(image) {
			t.Errorf("missing imported image %s", image)
		}
	}
	plan, err := metadata.Plan("", "", "base", false)
	if err != nil {
		t.Fatal(err)
	}
	for _, image := range []string{"python3-13", "python3-14", "scyllaridae-cleanpdf", "scyllaridae-whisper", "islandora-php83", "islandora-php84"} {
		if !containsString(plan.Images, image) {
			t.Errorf("base changes must rebuild %s", image)
		}
	}
	if containsString(plan.Images, "actions-runner") {
		t.Error("Ubuntu runner must not depend on the Alpine base")
	}
	for image, want := range map[string]string{"python3-13": "python3.13", "python3-14": "python3.14"} {
		if got := metadata.PublishedImage(image); got != want {
			t.Errorf("%s published name = %q, want %q", image, got, want)
		}
	}
}

func TestMigrationScripts(t *testing.T) {
	for _, script := range []string{"update-sha-imports.sh", "package-access-migration.sh"} {
		t.Run(script, func(t *testing.T) {
			command := exec.Command("bash", filepath.Join(repoRoot(t), "ci", "tests", script))
			if output, err := command.CombinedOutput(); err != nil {
				t.Fatalf("%v\n%s", err, output)
			}
		})
	}
}
