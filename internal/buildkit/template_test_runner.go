package buildkit

import (
	"bytes"
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

// RunTemplateTests executes each Compose template's retained smoke-test hook
// with the same bounded, keep-going presentation as image tests.
func RunTemplateTests(args []string, stdout, stderr io.Writer) int {
	var roots stringSliceFlag
	flags := flag.NewFlagSet("template-test", flag.ContinueOnError)
	flags.SetOutput(stderr)
	timeout := flags.Duration("timeout", 20*time.Minute, "maximum runtime for each template smoke test")
	keepGoing := flags.Bool("keep-going", false, "continue after a template smoke test fails")
	checkOnly := flags.Bool("check-only", false, "validate cross-template image pins without running smoke tests")
	flags.Var(&roots, "root", "template checkout containing scripts/test.sh; may be repeated")
	if err := flags.Parse(args); err != nil {
		return 2
	}
	roots = append(roots, flags.Args()...)
	if len(roots) == 0 {
		fmt.Fprintln(stderr, "at least one --root is required")
		return 2
	}
	if err := verifyTemplateImagePins(roots); err != nil {
		fmt.Fprintf(stderr, "template image pin drift: %v\n", err)
		return 1
	}
	if *checkOnly {
		fmt.Fprintf(stdout, "%d template contract(s) passed\n", len(roots))
		return 0
	}
	failed := 0
	for _, root := range roots {
		name := filepath.Base(filepath.Clean(root))
		fmt.Fprintf(stdout, "\n=== RUN template/%s\n", name)
		script := filepath.Join(root, "scripts", "test.sh")
		info, err := os.Stat(script)
		if err != nil || info.IsDir() {
			fmt.Fprintf(stderr, "--- FAIL: template/%s: scripts/test.sh is missing\n", name)
			failed++
			if !*keepGoing {
				break
			}
			continue
		}
		ctx, cancel := context.WithTimeout(context.Background(), *timeout)
		command := exec.CommandContext(ctx, "bash", script)
		command.Dir = root
		var output bytes.Buffer
		command.Stdout = io.MultiWriter(stdout, &output)
		command.Stderr = io.MultiWriter(stderr, &output)
		started := time.Now()
		err = command.Run()
		cancel()
		if ctx.Err() == context.DeadlineExceeded {
			err = fmt.Errorf("timed out after %s", *timeout)
		}
		if err != nil {
			fmt.Fprintf(stderr, "--- FAIL: template/%s (%s): %v\n", name, time.Since(started).Round(time.Millisecond), err)
			failed++
			if !*keepGoing {
				break
			}
			continue
		}
		fmt.Fprintf(stdout, "--- PASS: template/%s (%s)\n", name, time.Since(started).Round(time.Millisecond))
	}
	if failed > 0 {
		fmt.Fprintf(stderr, "\n%d template test(s) failed\n", failed)
		return 1
	}
	fmt.Fprintf(stdout, "\n%d template test(s) passed\n", len(roots))
	return 0
}

var templateImagePattern = regexp.MustCompile(`(?m)^\s*image:\s*([^\s@]+)@sha256:([a-f0-9]{64})\s*$`)

func verifyTemplateImagePins(roots []string) error {
	pins := map[string]map[string][]string{}
	for _, root := range roots {
		composePath, err := templateComposePath(root)
		if err != nil {
			return err
		}
		data, err := os.ReadFile(composePath) // #nosec G304 -- explicit operator-selected template checkout.
		if err != nil {
			return fmt.Errorf("read %s: %w", composePath, err)
		}
		for _, match := range templateImagePattern.FindAllStringSubmatch(string(data), -1) {
			if pins[match[1]] == nil {
				pins[match[1]] = map[string][]string{}
			}
			pins[match[1]][match[2]] = append(pins[match[1]][match[2]], filepath.Base(filepath.Clean(root)))
		}
	}
	var drift []string
	for image, digests := range pins {
		if len(digests) < 2 {
			continue
		}
		var values []string
		for digest, repos := range digests {
			sort.Strings(repos)
			values = append(values, fmt.Sprintf("%s in %s", digest[:12], strings.Join(repos, ",")))
		}
		sort.Strings(values)
		drift = append(drift, fmt.Sprintf("%s: %s", image, strings.Join(values, "; ")))
	}
	sort.Strings(drift)
	if len(drift) > 0 {
		return fmt.Errorf("same image tag resolves to different digests: %s", strings.Join(drift, " | "))
	}
	return nil
}

func templateComposePath(root string) (string, error) {
	for _, name := range []string{"compose.yaml", "docker-compose.yaml", "docker-compose.yml"} {
		path := filepath.Join(root, name)
		if info, err := os.Stat(path); err == nil && !info.IsDir() {
			return path, nil
		}
	}
	return "", fmt.Errorf("no Compose project file found in %s", root)
}
