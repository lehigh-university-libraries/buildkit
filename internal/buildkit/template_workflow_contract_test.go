package buildkit

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestTemplateContractWorkflowIsAutomaticAndSchedulesFullSmoke(t *testing.T) {
	t.Helper()
	_, source, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("resolve test source")
	}
	workflowPath := filepath.Join(filepath.Dir(source), "..", "..", ".github", "workflows", "template-contracts.yml")
	contents, err := os.ReadFile(workflowPath)
	if err != nil {
		t.Fatal(err)
	}
	workflow := string(contents)
	for _, required := range []string{
		"  pull_request:\n",
		"  push:\n",
		"  schedule:\n",
		"github.event_name == 'schedule' || (github.event_name == 'workflow_dispatch' && inputs.smoke)",
		"template-test --check-only",
		"template-test --keep-going",
		"internal/buildkit/template_workflow_contract_test.go",
		"git -C \"templates/${repository}\" rev-parse HEAD",
		"${GITHUB_STEP_SUMMARY}",
	} {
		if !strings.Contains(workflow, required) {
			t.Errorf("template contract workflow is missing %q", required)
		}
	}
}
