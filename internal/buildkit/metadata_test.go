package buildkit

import (
	"archive/zip"
	"bytes"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestMetadataTagsMatchForkedVersioning(t *testing.T) {
	root := repoRoot(t)
	metadata, err := LoadMetadata(root)
	if err != nil {
		t.Fatal(err)
	}
	nginxVersion, err := dockerfileArgDefault(filepath.Join(root, "images", "nginx", "Dockerfile"), "NGINX_VERSION")
	if err != nil {
		t.Fatal(err)
	}
	nginxTag := "nginx-" + normalizeDockerTag(normalizeVersion("nginx", nginxVersion))

	cases := []struct {
		image    string
		mode     string
		fallback string
		want     []string
	}{
		{image: "solr9", mode: "fallback", fallback: "local", want: []string{"local-9"}},
		{image: "archivesspace", mode: "fallback", fallback: "local", want: []string{"local"}},
		{image: "drupal-php83", mode: "fallback", fallback: "branch/name", want: []string{"branch-name-php83"}},
		{image: "drupal-php83", mode: "version", fallback: "branch/name", want: []string{nginxTag + "-php83"}},
		{image: "drupal-php84", mode: "version", fallback: "branch/name", want: []string{nginxTag + "-php84"}},
		{image: "islandora-php84", mode: "version", fallback: "branch/name", want: []string{nginxTag + "-php84"}},
		{image: "wp-php84", mode: "version", fallback: "branch/name", want: []string{nginxTag + "-php84"}},
		{image: "ojs-php83", mode: "version", fallback: "branch/name", want: []string{"3.5.0-5-php83", "3.5-php83", "3-php83", "php83"}},
		{image: "ojs-php84", mode: "version", fallback: "branch/name", want: []string{"3.5.0-5-php84", "3.5-php84", "3-php84", "php84", "latest-php84", "latest"}},
		{image: "omeka-s-php83", mode: "version", fallback: "branch/name", want: []string{"4.2.1-php83", "4.2-php83", "4-php83", "php83"}},
		{image: "omeka-s-php84", mode: "version", fallback: "branch/name", want: []string{"4.2.1-php84", "4.2-php84", "4-php84", "php84", "latest-php84", "latest"}},
		{image: "omeka-classic-php83", mode: "version", fallback: "branch/name", want: []string{"3.2.1-php83", "3.2-php83", "3-php83", "php83"}},
		{image: "omeka-classic-php84", mode: "version", fallback: "branch/name", want: []string{"3.2.1-php84", "3.2-php84", "3-php84", "php84", "latest-php84", "latest"}},
	}

	for _, tt := range cases {
		got, err := metadata.Tags(tt.image, tt.mode, tt.fallback)
		if err != nil {
			t.Fatalf("Tags(%s): %v", tt.image, err)
		}
		if len(got) != len(tt.want) {
			t.Fatalf("Tags(%s) = %v, want %v", tt.image, got, tt.want)
		}
		for index := range got {
			if got[index] != tt.want[index] {
				t.Fatalf("Tags(%s) = %v, want %v", tt.image, got, tt.want)
			}
		}
	}
}

func TestBundledPHPAppsDownloadVerifiedReleases(t *testing.T) {
	root := repoRoot(t)
	cases := []struct {
		image    string
		version  string
		checksum string
		dest     string
	}{
		{image: "ojs", version: "3.5.0-5", checksum: "fd59cb1add60ab4e56e40ed843ea43ff84af11f0b64c3940f2e03186ad11445e", dest: "/var/www/ojs"},
		{image: "omeka-s", version: "4.2.1", checksum: "cc27d1c7aca0209523d19aa285f4a08e29e34950dcc446951a7c1311de348e82", dest: "/var/www/omeka-s"},
		{image: "omeka-classic", version: "3.2.1", checksum: "2cb4d65511321cc5c009cb61516d9ed97378a800fc4a26eb46450c3c4ca230c2", dest: "/var/www/omeka-classic"},
	}

	for _, tt := range cases {
		dockerfile := filepath.Join(root, "images", tt.image, "Dockerfile")
		content, err := os.ReadFile(dockerfile)
		if err != nil {
			t.Fatal(err)
		}
		got := string(content)
		for _, want := range []string{
			"SOFTWARE_VERSION=" + tt.version,
			"SHA256=\"" + tt.checksum + "\"",
			"download.sh",
			"--sha256 \"${SHA256}\"",
			"--strip",
			"--dest " + tt.dest,
		} {
			if !strings.Contains(got, want) {
				t.Errorf("%s missing %q", dockerfile, want)
			}
		}
	}
}

func TestMarketedApplicationImagesOverrideInheritedLicense(t *testing.T) {
	root := repoRoot(t)
	cases := map[string]string{
		"archivesspace":      "ECL-2.0",
		"archivesspace-solr": "Apache-2.0 AND ECL-2.0",
		"drupal":             "GPL-2.0-or-later",
		"ojs":                "GPL-3.0-only",
		"omeka-classic":      "GPL-3.0-or-later",
		"omeka-s":            "GPL-3.0-only",
		"wp":                 "GPL-2.0-or-later",
	}

	for image, license := range cases {
		dockerfile := filepath.Join(root, "images", image, "Dockerfile")
		content, err := os.ReadFile(dockerfile)
		if err != nil {
			t.Fatal(err)
		}
		want := `LABEL org.opencontainers.image.licenses="` + license + `"`
		if !strings.Contains(string(content), want) {
			t.Errorf("%s must override the inherited license with %q", dockerfile, license)
		}
	}
}

func TestBundledApplicationImagesPreserveLicenseTexts(t *testing.T) {
	root := repoRoot(t)
	cases := map[string]string{
		"archivesspace":      "cp /archivesspace/COPYING /usr/share/licenses/archivesspace/COPYING",
		"archivesspace-solr": "cp /tmp/archivesspace-release/archivesspace/COPYING /usr/share/licenses/archivesspace-solr/COPYING",
		"ojs":                "cp docs/COPYING /usr/share/licenses/ojs/COPYING",
		"omeka-classic":      "cp /var/www/omeka-classic/license.txt /usr/share/licenses/omeka-classic/license.txt",
		"omeka-s":            "cp /var/www/omeka-s/LICENSE /usr/share/licenses/omeka-s/LICENSE",
	}

	for image, want := range cases {
		dockerfile := filepath.Join(root, "images", image, "Dockerfile")
		content, err := os.ReadFile(dockerfile)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(string(content), want) {
			t.Errorf("%s must preserve the bundled application's license text at a standard path", dockerfile)
		}
	}
}

func TestCurlHealthchecksFailOnHTTPError(t *testing.T) {
	root := repoRoot(t)
	entries, err := os.ReadDir(filepath.Join(root, "images"))
	if err != nil {
		t.Fatal(err)
	}

	for _, entry := range entries {
		dockerfile := filepath.Join(root, "images", entry.Name(), "Dockerfile")
		content, err := os.ReadFile(dockerfile)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			t.Fatal(err)
		}
		for _, line := range strings.Split(string(content), "\n") {
			if strings.Contains(line, "HEALTHCHECK") && strings.Contains(line, "curl ") && !strings.Contains(line, "curl -f") {
				t.Errorf("%s healthcheck must make curl fail on HTTP errors: %s", dockerfile, line)
			}
		}
	}
}

func TestComposeEnvUsesCurrentVersionedImageForGenericAlias(t *testing.T) {
	root := repoRoot(t)
	metadata, err := LoadMetadata(root)
	if err != nil {
		t.Fatal(err)
	}

	resolver := imageResolver{
		metadata:    metadata,
		repository:  "lehighlts",
		mode:        "fallback",
		fallbackTag: "local",
	}

	env := resolver.envFor("drupal-php83")
	if env["DRUPAL"] != "lehighlts/drupal:local-php83" {
		t.Fatalf("DRUPAL for drupal-php83 = %q", env["DRUPAL"])
	}
	if env["DRUPAL_PHP83"] != "lehighlts/drupal:local-php83" {
		t.Fatalf("DRUPAL_PHP83 = %q", env["DRUPAL_PHP83"])
	}
}

func TestCumulativeBranchPlanKeepsEarlierFallbackTagsForCompose(t *testing.T) {
	root := repoRoot(t)
	metadata, err := LoadMetadata(root)
	if err != nil {
		t.Fatal(err)
	}

	repository := t.TempDir()
	runGit := func(args ...string) string {
		t.Helper()
		commandArgs := append([]string{
			"-c", "user.name=Buildkit Tests",
			"-c", "user.email=buildkit-tests@example.com",
			"-c", "safe.directory=" + repository,
			"-C", repository,
		}, args...)
		command := exec.Command("git", commandArgs...)
		output, err := command.CombinedOutput()
		if err != nil {
			t.Fatalf("git %s: %v\n%s", strings.Join(args, " "), err, output)
		}
		return strings.TrimSpace(string(output))
	}
	write := func(path, content string) {
		t.Helper()
		fullPath := filepath.Join(repository, path)
		if err := os.MkdirAll(filepath.Dir(fullPath), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(fullPath, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	commit := func(message string) string {
		t.Helper()
		runGit("add", ".")
		runGit("commit", "-m", message)
		return runGit("rev-parse", "HEAD")
	}

	runGit("init")
	write("images/solr10/Dockerfile", "ARG SOFTWARE_VERSION=10.0.0\n")
	write("images/solr9/README.md", "Solr 9.9.0\n")
	base := commit("base")

	write("images/solr10/Dockerfile", "ARG SOFTWARE_VERSION=10.0.1\n")
	firstPush := commit("update solr")

	write("images/solr9/README.md", "Solr 9.9.1\n")
	head := commit("update solr9")

	metadata.Root = repository
	incremental, err := metadata.Plan(firstPush, head, "", false)
	if err != nil {
		t.Fatal(err)
	}
	if containsString(incremental.Images, "solr10") {
		t.Fatalf("incremental images unexpectedly retained solr10: %v", incremental.Images)
	}
	if !containsString(incremental.Images, "archivesspace-solr") {
		t.Fatalf("incremental Solr plan must retest archivesspace-solr: %v", incremental.Images)
	}

	cumulative, err := metadata.Plan(base, head, "", false)
	if err != nil {
		t.Fatal(err)
	}
	if !containsString(cumulative.Images, "solr10") {
		t.Fatalf("cumulative branch images lost solr10: %v", cumulative.Images)
	}

	fallbackImages := map[string]bool{}
	for _, image := range cumulative.Images {
		fallbackImages[image] = true
	}
	metadata.Root = root
	resolver := imageResolver{
		metadata:       metadata,
		repository:     "lehighlts",
		mode:           "fallback",
		fallbackTag:    "renovate.all-non-major-dependencies",
		buildImages:    fallbackImages,
		useBuildImages: true,
	}
	env := resolver.envFor("archivesspace-solr")
	if got, want := env["SOLR10"], "lehighlts/solr:renovate.all-non-major-dependencies-10"; got != want {
		t.Fatalf("SOLR10 = %q, want %q", got, want)
	}
	mariadbTag, err := metadata.FirstTag("mariadb11", "version", "main")
	if err != nil {
		t.Fatal(err)
	}
	if got, want := env["MARIADB11"], "lehighlts/mariadb:"+mariadbTag; got != want {
		t.Fatalf("MARIADB11 = %q, want unchanged image %q", got, want)
	}
}

func TestPushWorkflowUsesCumulativeFallbackImagesForBranchTags(t *testing.T) {
	root := repoRoot(t)
	workflowPath := filepath.Join(root, ".github", "workflows", "push.yml")
	content, err := os.ReadFile(workflowPath)
	if err != nil {
		t.Fatal(err)
	}
	got := string(content)

	for _, want := range []string{
		`fallback_images: ${{ steps.plan.outputs.fallback_images }}`,
		`DEFAULT_BRANCH: ${{ github.event.repository.default_branch || 'main' }}`,
		`MERGE_BASE="$(git merge-base "$HEAD" "origin/${DEFAULT_BRANCH}")"`,
		`./ci/image-metadata.sh plan --base "$MERGE_BASE" --head "$HEAD"`,
		`echo "fallback_images=${FALLBACK_IMAGES}" >> "$GITHUB_OUTPUT"`,
		`build-images: ${{ needs.plan.outputs.fallback_images }}`,
	} {
		if !strings.Contains(got, want) {
			t.Fatalf("%s missing cumulative fallback-image contract %q", workflowPath, want)
		}
	}

	uses := strings.Count(got, "build-images:")
	fallbackUses := strings.Count(got, `build-images: ${{ needs.plan.outputs.fallback_images }}`)
	if uses == 0 || fallbackUses != uses {
		t.Fatalf("%s passes fallback images to %d of %d build/test jobs", workflowPath, fallbackUses, uses)
	}
	if strings.Contains(got, `build-images: ${{ needs.plan.outputs.images }}`) {
		t.Fatalf("%s must not use the incremental build plan for fallback-tag resolution", workflowPath)
	}
}

func TestPlanSupportsLevelFourImages(t *testing.T) {
	root := repoRoot(t)
	metadata, err := LoadMetadata(root)
	if err != nil {
		t.Fatal(err)
	}

	plan, err := metadata.Plan("", "HEAD", "", true)
	if err != nil {
		t.Fatal(err)
	}
	if !containsString(plan.Level4, "islandora-php83") {
		t.Fatalf("level4 = %v, want islandora-php83", plan.Level4)
	}
	if !containsString(plan.Level4, "islandora-php84") {
		t.Fatalf("level4 = %v, want islandora-php84", plan.Level4)
	}
}

func TestPlannerImplementationPathsAreGlobal(t *testing.T) {
	global := []string{
		"cmd/buildkit/main.go",
		"go.mod",
		"go.sum",
		"internal/buildkit/metadata.go",
	}
	for _, path := range global {
		if !isGlobalPath(path) {
			t.Errorf("isGlobalPath(%q) = false, want true", path)
		}
	}

	if isGlobalPath("marketing/copy.md") {
		t.Error("unrelated documentation must not trigger a global image build")
	}
}

func TestMakefileNormalizesBranchWithoutShellReinterpolation(t *testing.T) {
	root := repoRoot(t)
	makefile := filepath.Join(root, "Makefile")
	content, err := os.ReadFile(makefile)
	if err != nil {
		t.Fatal(err)
	}
	got := string(content)
	if !strings.Contains(got, "rev-parse --abbrev-ref HEAD | sed -E") {
		t.Fatalf("%s must pipe the raw Git ref directly into normalization", makefile)
	}
	if strings.Contains(got, "BRANCH_RAW") {
		t.Fatalf("%s must not interpolate an untrusted raw branch into another shell command", makefile)
	}
	if !strings.Contains(got, `BRANCH="$(BRANCH)"`) {
		t.Fatalf("%s must quote the normalized branch passed to buildx bake", makefile)
	}
}

func TestBakeCacheRefsNormalizeSlashBranch(t *testing.T) {
	if _, err := exec.LookPath("docker"); err != nil {
		t.Skip("docker CLI is not available")
	}
	root := repoRoot(t)
	command := exec.Command("docker", "buildx", "bake", "--print", "solr9-amd64")
	command.Dir = root
	command.Env = append(os.Environ(), "BRANCH=feature/foo")
	output, err := command.CombinedOutput()
	if err != nil {
		t.Skipf("docker buildx bake is not available: %v\n%s", err, output)
	}
	got := string(output)
	if !strings.Contains(got, "solr9-feature-foo-amd64") {
		t.Fatalf("slash branch was not normalized in cache refs:\n%s", got)
	}
	if strings.Contains(got, "feature/foo") {
		t.Fatalf("slash branch leaked into a cache reference:\n%s", got)
	}
}

func TestUpdateSHAReadmeIsFailClosed(t *testing.T) {
	root := repoRoot(t)
	testScript := filepath.Join(root, "ci", "tests", "update-sha-readme.sh")
	command := exec.Command("bash", testScript)
	output, err := command.CombinedOutput()
	if err != nil {
		t.Fatalf("%s failed: %v\n%s", testScript, err, output)
	}
}

func TestPlanOutputUsesEmptyArraysForEmptyLevels(t *testing.T) {
	root := repoRoot(t)
	metadata, err := LoadMetadata(root)
	if err != nil {
		t.Fatal(err)
	}

	var output bytes.Buffer
	if err := runPlan(metadata, []string{"--image", "islandora-php83"}, &output); err != nil {
		t.Fatal(err)
	}
	got := output.String()
	for _, want := range []string{
		"level0=[]",
		"level1=[]",
		"level2=[]",
		"level3=[]",
		"test_level0=[]",
		"test_level1=[]",
		"test_level2=[]",
		"test_level3=[]",
		"level4=[\"islandora-php83\"]",
		"test_level4=[\"islandora-php83\"]",
	} {
		if !strings.Contains(got, want+"\n") {
			t.Fatalf("plan output missing %q:\n%s", want, got)
		}
	}
}

func TestMariaDBLongrunStartsServer(t *testing.T) {
	root := repoRoot(t)
	runFile := filepath.Join(root, "images", "mariadb11", "rootfs", "etc", "s6-overlay", "s6-rc.d", "mysqld", "run")
	content, err := os.ReadFile(runFile)
	if err != nil {
		t.Fatal(err)
	}
	got := string(content)
	if !strings.Contains(got, "/usr/bin/mariadbd") {
		t.Fatalf("%s must start the MariaDB server, got:\n%s", runFile, got)
	}
	if strings.Contains(got, "s6-setuidgid mysql mariadb --user mysql") {
		t.Fatalf("%s starts the MariaDB client instead of the server:\n%s", runFile, got)
	}
}

func TestOJSEnableBeaconTemplateUsesTruthyHelper(t *testing.T) {
	root := repoRoot(t)
	templateFile := filepath.Join(root, "images", "ojs", "rootfs", "etc", "confd", "templates", "config.inc.tmpl")
	content, err := os.ReadFile(templateFile)
	if err != nil {
		t.Fatal(err)
	}
	got := string(content)
	if strings.Contains(got, `if getenv "OJS_ENABLE_BEACON"`) {
		t.Fatalf("%s treats any non-empty OJS_ENABLE_BEACON value as On", templateFile)
	}
	if !strings.Contains(got, `define "booleanOnOff"`) || !strings.Contains(got, `enable_beacon = {{ template "booleanOnOff" (getenv "OJS_ENABLE_BEACON") }}`) {
		t.Fatalf("%s must render OJS_ENABLE_BEACON through the booleanOnOff helper", templateFile)
	}
}

func TestOJSConfigEscapesDoubleQuotedSecrets(t *testing.T) {
	root := repoRoot(t)
	templateFile := filepath.Join(root, "images", "ojs", "rootfs", "etc", "confd", "templates", "config.inc.tmpl")
	content, err := os.ReadFile(templateFile)
	if err != nil {
		t.Fatal(err)
	}
	got := string(content)
	for _, variable := range []string{"OJS_SECRET_KEY", "OJS_SALT", "OJS_API_KEY_SECRET"} {
		want := `template "doubleQuoteEscape" (getenv "` + variable + `")`
		if !strings.Contains(got, want) {
			t.Errorf("%s does not escape %s before rendering it in double quotes", templateFile, variable)
		}
	}
}

func TestOJSInstalledStateIsDurableAcrossConfdRendering(t *testing.T) {
	root := repoRoot(t)
	templateFile := filepath.Join(root, "images", "ojs", "rootfs", "etc", "confd", "templates", "config.inc.tmpl")
	content, err := os.ReadFile(templateFile)
	if err != nil {
		t.Fatal(err)
	}
	got := string(content)
	if strings.Contains(got, "installed = Off") {
		t.Fatalf("%s hardcodes the pre-install lifecycle state", templateFile)
	}
	if !strings.Contains(got, `installed = {{ template "booleanOnOff" (getenv "OJS_INSTALLED") }}`) {
		t.Fatalf("%s must render the reconciled OJS lifecycle state", templateFile)
	}

	for _, relative := range []string{
		"images/ojs/rootfs/etc/s6-overlay/s6-rc.d/confd-oneshot/dependencies.d/ojs-install-state",
		"images/ojs/rootfs/etc/s6-overlay/s6-rc.d/confd/dependencies.d/ojs-setup",
		"images/ojs/tests/ContinuousConfdPreservesInstalledState/docker-compose.yml",
	} {
		if _, err := os.Stat(filepath.Join(root, relative)); err != nil {
			t.Errorf("missing OJS lifecycle regression asset %s: %v", relative, err)
		}
	}

	setupFile := filepath.Join(root, "images", "ojs", "rootfs", "etc", "s6-overlay", "scripts", "ojs-setup.sh")
	setup, err := os.ReadFile(setupFile)
	if err != nil {
		t.Fatal(err)
	}
	stateIndex := strings.Index(string(setup), "/etc/s6-overlay/scripts/ojs-install-state.sh")
	renderIndex := strings.LastIndex(string(setup), "render_ojs_config")
	if stateIndex < 0 || renderIndex < 0 || stateIndex > renderIndex {
		t.Fatalf("%s must persist installed state before rerendering config", setupFile)
	}
}

func TestCredentialBearingConfdTemplatesAreNotWorldReadable(t *testing.T) {
	root := repoRoot(t)
	files := []string{
		"images/ojs/rootfs/etc/confd/conf.d/config.inc.toml",
		"images/tomcat9/rootfs/etc/confd/conf.d/tomcat-users.toml",
		"images/tomcat11/rootfs/etc/confd/conf.d/tomcat-users.toml",
	}

	for _, relative := range files {
		content, err := os.ReadFile(filepath.Join(root, relative))
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(string(content), `mode = "0640"`) {
			t.Errorf("%s must render service-readable credentials without world access", relative)
		}
	}
}

func TestOmekaDatabaseTemplatesEscapeDoubleQuotedValues(t *testing.T) {
	root := repoRoot(t)
	cases := []struct {
		file   string
		fields []string
	}{
		{
			file:   filepath.Join(root, "images", "omeka-s", "rootfs", "etc", "confd", "templates", "database.ini.tmpl"),
			fields: []string{"DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD"},
		},
		{
			file:   filepath.Join(root, "images", "omeka-classic", "rootfs", "etc", "confd", "templates", "db.ini.tmpl"),
			fields: []string{"DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD", "OMEKA_CLASSIC_TABLE_PREFIX"},
		},
	}

	for _, tt := range cases {
		content, err := os.ReadFile(tt.file)
		if err != nil {
			t.Fatal(err)
		}
		got := string(content)
		if !strings.Contains(got, `define "doubleQuoteEscape"`) {
			t.Errorf("%s does not define doubleQuoteEscape", tt.file)
		}
		for _, field := range tt.fields {
			want := `template "doubleQuoteEscape" (getenv "` + field + `")`
			if !strings.Contains(got, want) {
				t.Errorf("%s does not escape %s", tt.file, field)
			}
		}
	}
}

func TestArchivesSpaceJDBCCredentialsAreURLAndRubyEscaped(t *testing.T) {
	root := repoRoot(t)
	templateFile := filepath.Join(root, "images", "archivesspace", "rootfs", "etc", "confd", "templates", "archivesspace.config.rb.tmpl")
	content, err := os.ReadFile(templateFile)
	if err != nil {
		t.Fatal(err)
	}
	got := string(content)
	for _, field := range []string{"$dbUser", "$dbPassword"} {
		want := `URI.encode_www_form_component('{{ template "sqlEscape" ` + field + ` }}')`
		if !strings.Contains(got, want) {
			t.Errorf("%s must Ruby-escape and URL-encode %s", templateFile, field)
		}
	}
	for _, unsafe := range []string{
		`&user={{ template "sqlEscape" $dbUser }}`,
		`&password={{ template "sqlEscape" $dbPassword }}`,
	} {
		if strings.Contains(got, unsafe) {
			t.Errorf("%s inserts a raw JDBC credential: %s", templateFile, unsafe)
		}
	}

	composeFile := filepath.Join(root, "images", "archivesspace", "tests", "ServiceHealthcheck", "docker-compose.yml")
	compose, err := os.ReadFile(composeFile)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Count(string(compose), `DB_PASSWORD: "archive&=space%#password"`) != 2 {
		t.Errorf("%s must exercise URL-sensitive database credentials for both services", composeFile)
	}
}

func TestOmekaInstallersKeepAdminPasswordsOutOfCurlArguments(t *testing.T) {
	root := repoRoot(t)
	for _, image := range []string{"omeka-s", "omeka-classic"} {
		file := filepath.Join(root, "images", image, "rootfs", "etc", "s6-overlay", "scripts", image+"-setup.sh")
		content, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		got := string(content)
		if strings.Contains(got, `--data-urlencode "password=${`) || strings.Contains(got, `-d "user[password`) {
			t.Errorf("%s passes an admin password value in curl argv", file)
		}
		for _, want := range []string{"umask 077", `>"${form_dir}/admin-password"`, `@${form_dir}/admin-password`} {
			if !strings.Contains(got, want) {
				t.Errorf("%s missing secure form handling %q", file, want)
			}
		}
	}
}

func TestBaseVaultSecretsBootstrap(t *testing.T) {
	root := repoRoot(t)

	dockerfile := filepath.Join(root, "images", "base", "Dockerfile")
	dockerfileContent, err := os.ReadFile(dockerfile)
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		"APP_UID=100",
		"LIBOPS_SITE_ID=",
		"VAULT_ADDR=",
		"VAULT_AUTH_METHOD=gcp",
		"VAULT_GCP_AUTH_TYPE=iam",
	} {
		if !strings.Contains(string(dockerfileContent), want) {
			t.Fatalf("%s missing %q", dockerfile, want)
		}
	}

	dependency := filepath.Join(root, "images", "base", "rootfs", "etc", "s6-overlay", "s6-rc.d", "container-environment", "dependencies.d", "vault-secrets")
	if _, err := os.Stat(dependency); err != nil {
		t.Fatalf("container-environment must depend on vault-secrets: %v", err)
	}

	containerEnvironment := filepath.Join(root, "images", "base", "rootfs", "etc", "s6-overlay", "scripts", "container-environment.sh")
	containerEnvironmentContent, err := os.ReadFile(containerEnvironment)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(containerEnvironmentContent), "GOOGLE_APPLICATION_CREDENTIALS") {
		t.Fatalf("%s must preserve GOOGLE_APPLICATION_CREDENTIALS as a file path", containerEnvironment)
	}
	for _, want := range []string{"umask 077", "chmod 0700 /var/run/s6/container_environment", "chmod 0600"} {
		if !strings.Contains(string(containerEnvironmentContent), want) {
			t.Fatalf("%s must protect imported secret values with %q", containerEnvironment, want)
		}
	}

	script := filepath.Join(root, "images", "base", "rootfs", "etc", "s6-overlay", "scripts", "vault-secrets.sh")
	scriptContent, err := os.ReadFile(script)
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		"GOOGLE_APPLICATION_CREDENTIALS",
		"private_key_id",
		"openssl dgst -sha256 -sign",
		"secret-organization",
		"secret-project",
		"secret-site",
		"chmod 0400",
		"chown \"${app_uid}:0\"",
		`if [[ "${name}" = "DB_ROOT_PASSWORD" ]]`,
		"chown 0:0",
	} {
		if !strings.Contains(string(scriptContent), want) {
			t.Fatalf("%s missing %q", script, want)
		}
	}
}

func TestContainerEnvironmentEscapesExeclineValues(t *testing.T) {
	root := repoRoot(t)
	file := filepath.Join(root, "images", "base", "rootfs", "etc", "s6-overlay", "scripts", "container-environment.sh")
	content, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	got := string(content)
	if !strings.Contains(got, `define "execlineEscape"`) {
		t.Fatalf("%s must define an execline value escape helper", file)
	}
	if !strings.Contains(got, `template \"execlineEscape\"`) {
		t.Fatalf("%s must escape values before generating the execline import script", file)
	}
}

func TestWithContEnvApplicationLongrunsDropDatabaseRootPassword(t *testing.T) {
	root := repoRoot(t)
	files := []string{
		filepath.Join(root, "images", "archivesspace", "rootfs", "usr", "local", "bin", "archivesspace-startup.sh"),
		filepath.Join(root, "images", "solr9", "rootfs", "etc", "s6-overlay", "s6-rc.d", "solr", "run"),
		filepath.Join(root, "images", "solr10", "rootfs", "etc", "s6-overlay", "s6-rc.d", "solr", "run"),
		filepath.Join(root, "images", "tomcat9", "rootfs", "etc", "s6-overlay", "s6-rc.d", "tomcat", "run"),
		filepath.Join(root, "images", "tomcat11", "rootfs", "etc", "s6-overlay", "s6-rc.d", "tomcat", "run"),
	}

	for _, file := range files {
		content, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		got := string(content)
		unsetIndex := strings.Index(got, "unset DB_ROOT_PASSWORD")
		execIndex := strings.LastIndex(got, "exec ")
		if unsetIndex < 0 || execIndex < 0 || unsetIndex > execIndex {
			t.Errorf("%s must unset DB_ROOT_PASSWORD before its final exec", file)
		}
	}
}

func TestApplicationDatabaseBootstrapIsExplicit(t *testing.T) {
	root := repoRoot(t)
	baseDockerfile := filepath.Join(root, "images", "base", "Dockerfile")
	content, err := os.ReadFile(baseDockerfile)
	if err != nil {
		t.Fatal(err)
	}
	base := string(content)
	if !strings.Contains(base, "DB_BOOTSTRAP_ENABLED=false") {
		t.Fatalf("%s must disable application-side database bootstrap by default", baseDockerfile)
	}
	if strings.Contains(base, "DB_ROOT_PASSWORD=password") {
		t.Fatalf("%s must not provide a placeholder database root password", baseDockerfile)
	}

	files := []string{
		filepath.Join(root, "images", "drupal", "rootfs", "etc", "s6-overlay", "scripts", "install.sh"),
		filepath.Join(root, "images", "ojs", "rootfs", "etc", "s6-overlay", "scripts", "ojs-setup.sh"),
		filepath.Join(root, "images", "omeka-s", "rootfs", "etc", "s6-overlay", "scripts", "omeka-s-setup.sh"),
		filepath.Join(root, "images", "omeka-classic", "rootfs", "etc", "s6-overlay", "scripts", "omeka-classic-setup.sh"),
		filepath.Join(root, "images", "wp", "rootfs", "etc", "s6-overlay", "scripts", "wordpress-setup.sh"),
		filepath.Join(root, "images", "archivesspace", "rootfs", "usr", "local", "bin", "archivesspace-startup.sh"),
	}
	for _, file := range files {
		content, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(string(content), "database_bootstrap_if_enabled") {
			t.Errorf("%s must gate database creation behind the explicit bootstrap helper", file)
		}
	}
}

func TestBaseImageDoesNotShipJWTKeyMaterial(t *testing.T) {
	root := repoRoot(t)
	for _, name := range []string{"JWT_PRIVATE_KEY", "JWT_PUBLIC_KEY"} {
		path := filepath.Join(root, "images", "base", "rootfs", "etc", "defaults", name)
		content, err := os.ReadFile(path)
		if err != nil {
			t.Fatalf("read %s: %v", path, err)
		}
		if strings.TrimSpace(string(content)) != "" {
			t.Errorf("%s must not contain reusable JWT key material", path)
		}
	}
}

func TestPublishedBaseImageRefreshesPackageMetadata(t *testing.T) {
	root := repoRoot(t)
	workflowPath := filepath.Join(root, ".github", "workflows", "build.yml")
	workflow, err := os.ReadFile(workflowPath)
	if err != nil {
		t.Fatalf("read %s: %v", workflowPath, err)
	}
	if !strings.Contains(string(workflow), `"BASE_NO_CACHE=${{ inputs.image == 'base' }}"`) {
		t.Fatalf("%s must disable the BuildKit cache for published base rebuilds", workflowPath)
	}

	bakePath := filepath.Join(root, "docker-bake.hcl")
	bake, err := os.ReadFile(bakePath)
	if err != nil {
		t.Fatalf("read %s: %v", bakePath, err)
	}
	if !strings.Contains(string(bake), "no-cache = BASE_NO_CACHE") {
		t.Fatalf("%s must apply BASE_NO_CACHE to the base target", bakePath)
	}
}

func TestPushWorkflowPublishesRequiredLevelFourGate(t *testing.T) {
	root := repoRoot(t)
	workflowPath := filepath.Join(root, ".github", "workflows", "push.yml")
	workflow, err := os.ReadFile(workflowPath)
	if err != nil {
		t.Fatalf("read %s: %v", workflowPath, err)
	}
	for _, required := range []string{
		"  test-level-4-matrix:\n",
		"  test-level-4:\n",
		"    needs: [test-level-4-matrix]\n",
		"          RESULT: ${{ needs.test-level-4-matrix.result }}\n",
	} {
		if !strings.Contains(string(workflow), required) {
			t.Errorf("%s must contain required level-4 gate contract %q", workflowPath, required)
		}
	}
}

func TestBaseOwnsSharedComposeInitializationTools(t *testing.T) {
	root := repoRoot(t)
	for _, name := range []string{"init-database.sh", "generate-compose-secrets.sh", "generate-certs.sh"} {
		path := filepath.Join(root, "images", "base", "rootfs", "usr", "local", "bin", name)
		info, err := os.Stat(path)
		if err != nil {
			t.Fatalf("shared initialization tool %s is missing: %v", name, err)
		}
		if info.Mode().Perm()&0o111 == 0 {
			t.Errorf("shared initialization tool %s is not executable", name)
		}
		contents, err := os.ReadFile(path)
		if err != nil {
			t.Fatalf("read shared initialization tool %s: %v", name, err)
		}
		if !strings.HasPrefix(string(contents), "#!/usr/bin/env bash\n") {
			t.Errorf("shared initialization tool %s must run without an initialized s6 environment", name)
		}
	}
	secrets, err := os.ReadFile(filepath.Join(root, "images", "base", "rootfs", "usr", "local", "bin", "generate-compose-secrets.sh"))
	if err != nil {
		t.Fatal(err)
	}
	for _, required := range []string{".secrets // {}", "SECRET_FORMAT_", "laravel-base64", "salt74", "openssl rand"} {
		if !strings.Contains(string(secrets), required) {
			t.Errorf("canonical secret generator must contain %q", required)
		}
	}
}

func TestMarketedApplicationImagesDoNotShipKnownCredentials(t *testing.T) {
	root := repoRoot(t)
	images := []string{"archivesspace", "drupal", "ojs", "omeka-s", "omeka-classic", "wp"}
	banned := []string{
		"DB_PASSWORD=changeme",
		"DRUPAL_DEFAULT_ACCOUNT_PASSWORD=password",
		"DRUPAL_DEFAULT_SALT=9PPaL0",
		"OJS_SALT=changeme",
		"OJS_API_KEY_SECRET=changeme",
		"OJS_SECRET_KEY=changeme",
		"OJS_ADMIN_PASSWORD=changeme",
		"OMEKA_S_ADMIN_PASSWORD=changeme",
		"OMEKA_CLASSIC_ADMIN_PASSWORD=changeme",
		"WORDPRESS_ADMIN_PASSWORD=changeme",
		"WORDPRESS_AUTH_KEY=changeme",
		"WORDPRESS_NONCE_SALT=changeme",
	}
	for _, image := range images {
		file := filepath.Join(root, "images", image, "Dockerfile")
		content, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		got := string(content)
		for _, value := range banned {
			if strings.Contains(got, value) {
				t.Errorf("%s ships known credential %q", file, value)
			}
		}
	}
}

func TestNetworkServicesDoNotShipKnownCredentials(t *testing.T) {
	root := repoRoot(t)
	cases := []struct {
		file   string
		banned []string
	}{
		{file: filepath.Join(root, "images", "base", "Dockerfile"), banned: []string{"DB_PASSWORD=password", "JWT_ADMIN_TOKEN=islandora"}},
		{file: filepath.Join(root, "images", "tomcat9", "Dockerfile"), banned: []string{"TOMCAT_ADMIN_PASSWORD=password", "TOMCAT_MANAGER_REMOTE_ADDRESS_VALVE=^.*$", "TOMCAT_MANAGER_REMOTE_ADDRESS_VALVE=^(127[.]|::1$)"}},
		{file: filepath.Join(root, "images", "tomcat11", "Dockerfile"), banned: []string{"TOMCAT_ADMIN_PASSWORD=password", "TOMCAT_MANAGER_REMOTE_ADDRESS_VALVE=^.*$", "TOMCAT_MANAGER_REMOTE_ADDRESS_VALVE=^(127[.]|::1$)"}},
	}
	for _, tt := range cases {
		content, err := os.ReadFile(tt.file)
		if err != nil {
			t.Fatal(err)
		}
		for _, value := range tt.banned {
			if strings.Contains(string(content), value) {
				t.Errorf("%s ships known credential %q", tt.file, value)
			}
		}
	}
}

func TestOJSSetupInstallsAgainstExternalDatabaseHost(t *testing.T) {
	root := repoRoot(t)
	library := filepath.Join(root, "images", "base", "rootfs", "usr", "local", "share", "libops", "database.sh")
	environmentLibrary := filepath.Join(root, "images", "base", "rootfs", "usr", "local", "share", "libops", "environment.sh")
	setup := filepath.Join(root, "images", "ojs", "rootfs", "etc", "s6-overlay", "scripts", "ojs-setup.sh")
	harness := filepath.Join(root, "internal", "buildkit", "testdata", "ojs-external-database.sh")
	command := exec.Command("bash", harness, library, environmentLibrary, setup)
	if output, err := command.CombinedOutput(); err != nil {
		t.Fatalf("external database setup stub failed: %v\n%s", err, output)
	}
}

func TestNonDatabaseLongRunsDropDatabaseRootPassword(t *testing.T) {
	root := repoRoot(t)
	files := []string{
		filepath.Join(root, "images", "base", "rootfs", "etc", "s6-overlay", "s6-rc.d", "confd", "run"),
		filepath.Join(root, "images", "nginx", "rootfs", "etc", "s6-overlay", "s6-rc.d", "nginx", "run"),
		filepath.Join(root, "images", "php83", "rootfs", "etc", "s6-overlay", "s6-rc.d", "fpm", "run"),
		filepath.Join(root, "images", "php84", "rootfs", "etc", "s6-overlay", "s6-rc.d", "fpm", "run"),
		filepath.Join(root, "images", "scyllaridae", "rootfs", "etc", "s6-overlay", "s6-rc.d", "scyllaridae", "run"),
	}
	for _, file := range files {
		content, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(string(content), "unset DB_ROOT_PASSWORD") && !strings.Contains(string(content), "unexport DB_ROOT_PASSWORD") {
			t.Errorf("%s retains DB_ROOT_PASSWORD in a non-database longrun", file)
		}
	}
}

func TestPHPLongRunsDropSetupOnlyAdminPasswords(t *testing.T) {
	root := repoRoot(t)
	files := []string{
		filepath.Join(root, "images", "nginx", "rootfs", "etc", "s6-overlay", "s6-rc.d", "nginx", "run"),
		filepath.Join(root, "images", "php83", "rootfs", "etc", "s6-overlay", "s6-rc.d", "fpm", "run"),
		filepath.Join(root, "images", "php84", "rootfs", "etc", "s6-overlay", "s6-rc.d", "fpm", "run"),
	}
	variables := []string{
		"DRUPAL_DEFAULT_ACCOUNT_PASSWORD",
		"OJS_ADMIN_PASSWORD",
		"OMEKA_CLASSIC_ADMIN_PASSWORD",
		"OMEKA_S_ADMIN_PASSWORD",
		"WORDPRESS_ADMIN_PASSWORD",
	}
	for _, file := range files {
		content, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		got := string(content)
		for _, variable := range variables {
			if !strings.Contains(got, variable) {
				t.Errorf("%s retains setup-only %s", file, variable)
			}
		}
	}
}

func TestWordPressAdminPasswordUsesPromptInput(t *testing.T) {
	root := repoRoot(t)
	file := filepath.Join(root, "images", "wp", "rootfs", "etc", "s6-overlay", "scripts", "wordpress-setup.sh")
	content, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	got := string(content)
	if strings.Contains(got, `--admin_password="${WORDPRESS_ADMIN_PASSWORD}"`) {
		t.Fatalf("%s exposes the administrator password in wp-cli argv", file)
	}
	if !strings.Contains(got, `--prompt=admin_password`) || !strings.Contains(got, `printf '%s\n' "${WORDPRESS_ADMIN_PASSWORD}"`) {
		t.Fatalf("%s must provide the administrator password through wp-cli prompt input", file)
	}
}

func TestWordPressSetupRunsWPCLIAsServiceAccount(t *testing.T) {
	root := repoRoot(t)
	file := filepath.Join(root, "images", "wp", "rootfs", "etc", "s6-overlay", "scripts", "wordpress-setup.sh")
	content, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	got := string(content)
	if !strings.Contains(got, "s6-setuidgid nginx wp --path=/var/www/bedrock/web/wp") {
		t.Fatalf("%s must run setup through the WordPress service account", file)
	}
	if strings.Contains(got, "wp --allow-root") {
		t.Fatalf("%s must not let setup create application files as root", file)
	}
}

func TestTomcatManagerDefaultAllowsOnlyLoopback(t *testing.T) {
	root := repoRoot(t)
	for _, version := range []string{"tomcat9", "tomcat11"} {
		file := filepath.Join(root, "images", version, "Dockerfile")
		content, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(string(content), "TOMCAT_MANAGER_REMOTE_ADDRESS_VALVE=^(127[.].*|::1)$") {
			t.Errorf("%s does not restrict the manager valve to complete loopback addresses", file)
		}

		templateFile := filepath.Join(root, "images", version, "rootfs", "etc", "confd", "templates", "tomcat-users.xml.tmpl")
		templateContent, err := os.ReadFile(templateFile)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(string(templateContent), `template "xmlAttributeEscape" (getenv "TOMCAT_ADMIN_PASSWORD")`) {
			t.Errorf("%s does not XML-escape the administrator password", templateFile)
		}
		if strings.Contains(string(templateContent), `$escaped = replace`) {
			t.Errorf("%s uses template reassignment unsupported by the bundled confd", templateFile)
		}

		readmeFile := filepath.Join(root, "images", version, "README.md")
		readmeContent, err := os.ReadFile(readmeFile)
		if err != nil {
			t.Fatal(err)
		}
		for _, want := range []string{"-p 127.0.0.1:8080:8080", `--env TOMCAT_MANAGER_REMOTE_ADDRESS_VALVE='.*'`} {
			if !strings.Contains(string(readmeContent), want) {
				t.Errorf("%s local manager example missing %q", readmeFile, want)
			}
		}
	}
}

func TestDrupalInstalledQueryDoesNotInterpolateDatabaseName(t *testing.T) {
	root := repoRoot(t)
	library := filepath.Join(root, "images", "base", "rootfs", "usr", "local", "share", "libops", "database.sh")
	environmentLibrary := filepath.Join(root, "images", "base", "rootfs", "usr", "local", "share", "libops", "environment.sh")
	setup := filepath.Join(root, "images", "drupal", "rootfs", "etc", "s6-overlay", "scripts", "install.sh")
	harness := filepath.Join(root, "internal", "buildkit", "testdata", "drupal-database-query.sh")
	command := exec.Command("bash", harness, library, environmentLibrary, setup)
	if output, err := command.CombinedOutput(); err != nil {
		t.Fatalf("Drupal installed query interpolation test failed: %v\n%s", err, output)
	}
}

func TestDrupalInstallerRestoresRuntimeSettingsOnce(t *testing.T) {
	root := repoRoot(t)
	library := filepath.Join(root, "images", "base", "rootfs", "usr", "local", "share", "libops", "database.sh")
	environmentLibrary := filepath.Join(root, "images", "base", "rootfs", "usr", "local", "share", "libops", "environment.sh")
	setup := filepath.Join(root, "images", "drupal", "rootfs", "etc", "s6-overlay", "scripts", "install.sh")
	drupalRoot := t.TempDir()
	settingsDirectory := filepath.Join(drupalRoot, "web", "sites", "default")
	if err := os.MkdirAll(settingsDirectory, 0o755); err != nil {
		t.Fatalf("create Drupal settings directory: %v", err)
	}
	settingsPath := filepath.Join(settingsDirectory, "settings.php")
	if err := os.WriteFile(settingsPath, []byte("<?php\n"), 0o644); err != nil {
		t.Fatalf("write Drupal settings fixture: %v", err)
	}
	defaultsPath := filepath.Join(t.TempDir(), "default_settings.txt")
	defaults := "$settings['file_private_path'] = '/var/www/drupal/private/';\nrequire '/etc/drupal/libops.settings.php';\n"
	if err := os.WriteFile(defaultsPath, []byte(defaults), 0o644); err != nil {
		t.Fatalf("write LibOps settings fixture: %v", err)
	}

	harness := filepath.Join(root, "internal", "buildkit", "testdata", "drupal-runtime-settings.sh")
	command := exec.Command("bash", harness, library, environmentLibrary, setup, drupalRoot, defaultsPath)
	if output, err := command.CombinedOutput(); err != nil {
		t.Fatalf("Drupal runtime settings recovery test failed: %v\n%s", err, output)
	}
}

func TestCommandHelpersDoNotEvalArguments(t *testing.T) {
	root := repoRoot(t)
	files := []string{
		filepath.Join(root, "images", "base", "rootfs", "usr", "local", "bin", "download.sh"),
		filepath.Join(root, "images", "base", "rootfs", "usr", "local", "bin", "create-service-user.sh"),
		filepath.Join(root, "images", "base", "rootfs", "usr", "local", "bin", "cleanup.sh"),
		filepath.Join(root, "images", "base", "rootfs", "usr", "local", "bin", "confd-import-environment.sh"),
		filepath.Join(root, "images", "base", "rootfs", "usr", "local", "bin", "wait-for-open-port.sh"),
		filepath.Join(root, "images", "base", "rootfs", "usr", "local", "bin", "confd-render-templates.sh"),
		filepath.Join(root, "images", "drupal", "rootfs", "usr", "local", "bin", "install-drupal-site.sh"),
	}
	for _, file := range files {
		content, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		if strings.Contains(string(content), "eval "+"set --") {
			t.Errorf("%s evaluates reconstructed command-line arguments", file)
		}

		marker := filepath.Join(t.TempDir(), "argument-was-executed")
		malicious := `space "$(touch ` + marker + `)" 'quoted'`
		command := exec.Command("bash", file, "--help", malicious)
		command.Env = append(os.Environ(), "DOWNLOAD_CACHE_DIRECTORY=/tmp")
		_ = command.Run()
		if _, err := os.Stat(marker); !os.IsNotExist(err) {
			t.Errorf("%s executed a command embedded in an argument", file)
		}
	}
}

func TestDatabaseHelpersDoNotForwardPasswordsInArguments(t *testing.T) {
	root := repoRoot(t)
	cases := []struct {
		file   string
		banned []string
	}{
		{
			file: filepath.Join(root, "images", "base", "rootfs", "usr", "local", "bin", "create-database.sh"),
			banned: []string{
				`--password "${PASSWORD}"`,
			},
		},
		{
			file: filepath.Join(root, "images", "base", "rootfs", "usr", "local", "bin", "execute-sql-file.sh"),
			banned: []string{
				`--password "${PASSWORD}"`,
				`--password="${PASSWORD}"`,
			},
		},
		{
			file: filepath.Join(root, "images", "base", "rootfs", "usr", "local", "bin", "wait-for-database.sh"),
			banned: []string{
				`--password="${PASSWORD}"`,
			},
		},
	}
	for _, tt := range cases {
		content, err := os.ReadFile(tt.file)
		if err != nil {
			t.Fatal(err)
		}
		for _, banned := range tt.banned {
			if strings.Contains(string(content), banned) {
				t.Errorf("%s exposes a password through child argv: %s", tt.file, banned)
			}
		}
	}
}

func TestDrupalInstallersKeepDatabasePasswordsOutOfArguments(t *testing.T) {
	root := repoRoot(t)
	primary := filepath.Join(root, "images", "drupal", "rootfs", "etc", "s6-overlay", "scripts", "install.sh")
	helper := filepath.Join(root, "images", "drupal", "rootfs", "usr", "local", "bin", "install-drupal-site.sh")
	islandora := filepath.Join(root, "images", "islandora", "rootfs", "etc", "islandora", "utilities.sh")
	encoder := filepath.Join(root, "images", "drupal", "rootfs", "usr", "local", "share", "libops", "drupal-uri-encode.php")

	for _, file := range []string{primary, helper, islandora} {
		content, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		got := string(content)
		for _, banned := range []string{"--db-url=", "--db-password", "--account-pass="} {
			if strings.Contains(got, banned) {
				t.Errorf("%s still forwards a credential using %q", file, banned)
			}
		}
	}

	helperContent, err := os.ReadFile(helper)
	if err != nil {
		t.Fatal(err)
	}
	got := string(helperContent)
	for _, want := range []string{
		`/usr/local/share/libops/drupal-uri-encode.php`,
		`DRUSH_COMMAND_SITE_INSTALL_OPTIONS_DB_URL="${drush_database_url}"`,
		`DB_PASSWORD=${LIBOPS_DRUPAL_INSTALL_DB_PASSWORD:-}`,
	} {
		if !strings.Contains(got, want) {
			t.Errorf("%s missing %q", helper, want)
		}
	}

	encoderContent, err := os.ReadFile(encoder)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(encoderContent), `rawurlencode((string) getenv('LIBOPS_DRUPAL_URI_COMPONENT'))`) {
		t.Errorf("%s must URI-encode the environment-provided component", encoder)
	}
}

func TestRuntimePHPProgramsAreCheckedIn(t *testing.T) {
	root := repoRoot(t)
	cases := []struct {
		launcher   string
		program    string
		invocation string
	}{
		{
			launcher:   "images/drupal/rootfs/etc/s6-overlay/scripts/install.sh",
			program:    "images/drupal/rootfs/usr/local/share/libops/drupal-uri-encode.php",
			invocation: "/usr/local/share/libops/drupal-uri-encode.php",
		},
		{
			launcher:   "images/drupal/rootfs/usr/local/bin/install-drupal-site.sh",
			program:    "images/drupal/rootfs/usr/local/share/libops/drupal-uri-encode.php",
			invocation: "/usr/local/share/libops/drupal-uri-encode.php",
		},
		{
			launcher:   "images/islandora/rootfs/etc/islandora/utilities.sh",
			program:    "images/islandora/rootfs/etc/islandora/config-sync-directory.php",
			invocation: "php:script /etc/islandora/config-sync-directory.php",
		},
		{
			launcher:   "images/wp/rootfs/etc/s6-overlay/scripts/wordpress-setup.sh",
			program:    "images/wp/rootfs/usr/local/share/libops/wordpress-home.php",
			invocation: "php /usr/local/share/libops/wordpress-home.php",
		},
	}

	for _, tt := range cases {
		launcher, err := os.ReadFile(filepath.Join(root, tt.launcher))
		if err != nil {
			t.Fatal(err)
		}
		got := string(launcher)
		if strings.Contains(got, "php -r") || strings.Contains(got, "php:eval") {
			t.Errorf("%s embeds PHP instead of invoking a checked-in program", tt.launcher)
		}
		if !strings.Contains(got, tt.invocation) {
			t.Errorf("%s does not invoke checked-in program %s", tt.launcher, tt.program)
		}
		program, err := os.ReadFile(filepath.Join(root, tt.program))
		if err != nil {
			t.Fatal(err)
		}
		if !strings.HasPrefix(string(program), "<?php\n") {
			t.Errorf("%s is not a PHP program", tt.program)
		}
	}
}

func TestGenericDrupalInstallerEncodesDatabaseURLWithoutArgumentExposure(t *testing.T) {
	root := repoRoot(t)
	helper := filepath.Join(root, "images", "drupal", "rootfs", "usr", "local", "bin", "install-drupal-site.sh")
	binDir := t.TempDir()
	outputFile := filepath.Join(t.TempDir(), "drush-db-url")
	rawPassword := `p"a\ss'word&+=:/?#%`

	executeSQL := filepath.Join(binDir, "execute-sql-file.sh")
	executeSQLScript, err := os.ReadFile(filepath.Join(root, "internal", "buildkit", "testdata", "execute-sql-zero.sh"))
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(executeSQL, executeSQLScript, 0o755); err != nil {
		t.Fatal(err)
	}
	drush := filepath.Join(binDir, "drush")
	drushScript, err := os.ReadFile(filepath.Join(root, "internal", "buildkit", "testdata", "drush-db-url-stub.sh"))
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(drush, drushScript, 0o755); err != nil {
		t.Fatal(err)
	}

	command := exec.Command("bash", helper,
		"--host", "database",
		"--port", "3306",
		"--db-user", "user@name",
		"--db-name", "drupal/name",
		"standard", "--sites-subdir=default",
	)
	command.Env = append(os.Environ(),
		"PATH="+binDir+":"+os.Getenv("PATH"),
		"LIBOPS_DRUPAL_URI_ENCODER="+filepath.Join(root, "images", "drupal", "rootfs", "usr", "local", "share", "libops", "drupal-uri-encode.php"),
		"LIBOPS_DRUPAL_INSTALL_DB_PASSWORD="+rawPassword,
		"EXPECTED_RAW_PASSWORD="+rawPassword,
		"DRUSH_OUTPUT="+outputFile,
	)
	if output, err := command.CombinedOutput(); err != nil {
		t.Fatalf("generic Drupal installer failed: %v\n%s", err, output)
	}
	url, err := os.ReadFile(outputFile)
	if err != nil {
		t.Fatal(err)
	}
	want := "mysql://user%40name:p%22a%5Css%27word%26%2B%3D%3A%2F%3F%23%25@database:3306/drupal%2Fname\n"
	if string(url) != want {
		t.Fatalf("encoded Drush database URL = %q, want %q", url, want)
	}
}

func TestPHPRuntimeSecretConfigsAreGroupReadableOnly(t *testing.T) {
	root := repoRoot(t)
	files := []string{
		"images/drupal/rootfs/etc/confd/conf.d/drupal.libops.settings.toml",
		"images/wp/rootfs/etc/confd/conf.d/wordpress.application.toml",
	}
	for _, relative := range files {
		content, err := os.ReadFile(filepath.Join(root, relative))
		if err != nil {
			t.Fatal(err)
		}
		got := string(content)
		if !strings.Contains(got, "uid = 0\ngid = 101\nmode = \"0640\"") {
			t.Errorf("%s must render root-owned, nginx-group-readable runtime secrets", relative)
		}
	}

	developmentScript, err := os.ReadFile(filepath.Join(root, "images", "islandora", "rootfs", "etc", "s6-overlay", "scripts", "development-environment.sh"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(developmentScript), "groupmod") {
		t.Error("Islandora development UID remapping must preserve the stable nginx GID used by runtime secret configs")
	}
}

func TestVersionedImageReadmesMatchDockerfiles(t *testing.T) {
	root := repoRoot(t)
	images := []string{"mariadb11", "tomcat11"}
	for _, image := range images {
		version, err := dockerfileArgDefault(filepath.Join(root, "images", image, "Dockerfile"), "SOFTWARE_VERSION")
		if err != nil {
			t.Fatal(err)
		}
		version = normalizeVersion(image, version)
		readme := filepath.Join(root, "images", image, "README.md")
		content, err := os.ReadFile(readme)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(string(content), "version "+version+".") {
			t.Errorf("%s does not document Dockerfile SOFTWARE_VERSION %s", readme, version)
		}
	}
}

func TestDownloadZipStripRequiresOneTopLevelDirectory(t *testing.T) {
	root := repoRoot(t)
	script := filepath.Join(root, "images", "base", "rootfs", "usr", "local", "bin", "download.sh")

	invalidZip := filepath.Join(t.TempDir(), "invalid.zip")
	writeTestZip(t, invalidZip, map[string]string{
		"first/file.txt":  "first",
		"second/file.txt": "second",
	})
	invalidDest := t.TempDir()
	harness := filepath.Join(root, "internal", "buildkit", "testdata", "download-zip-strip.sh")
	command := exec.Command("bash", harness, script, invalidZip, invalidDest)
	output, err := command.CombinedOutput()
	if err == nil || !strings.Contains(string(output), "exactly one top-level directory") {
		t.Fatalf("multi-root ZIP was not rejected safely: err=%v output=%s", err, output)
	}

	validZip := filepath.Join(t.TempDir(), "valid.zip")
	writeTestZip(t, validZip, map[string]string{"release/file.txt": "payload"})
	validDest := t.TempDir()
	command = exec.Command("bash", harness, script, validZip, validDest)
	if output, err := command.CombinedOutput(); err != nil {
		t.Fatalf("single-root ZIP strip failed: %v\n%s", err, output)
	}
	content, err := os.ReadFile(filepath.Join(validDest, "file.txt"))
	if err != nil {
		t.Fatal(err)
	}
	if string(content) != "payload" {
		t.Fatalf("stripped ZIP payload = %q", content)
	}
}

func writeTestZip(t *testing.T, path string, entries map[string]string) {
	t.Helper()
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	archive := zip.NewWriter(file)
	for name, content := range entries {
		entry, err := archive.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := io.WriteString(entry, content); err != nil {
			t.Fatal(err)
		}
	}
	if err := archive.Close(); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
}

func repoRoot(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "docker-bake.hcl")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatal("could not find docker-bake.hcl")
		}
		dir = parent
	}
}
