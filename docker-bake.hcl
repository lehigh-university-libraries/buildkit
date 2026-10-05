ARCHES = [
  "amd64",
  "arm64",
]
###############################################################################
# Matrix-derived local and architecture targets.
###############################################################################
target "image" {
  matrix = {
    image = IMAGES
  }
  name = image
  inherits = ["${image}-common"]
  contexts = dependencies(image, image == "scyllaridae-whisper" ? "amd64" : "")
  cache-from = cacheFrom(image, hostArch())
  tags = tags(image, "")
}

target "image-arch" {
  matrix = {
    item = flatten([for image in IMAGES: [for arch in imageArches(image): {image = image, arch = arch}]])
  }
  name = "${item.image}-${item.arch}"
  inherits = ["${item.image}-common", "${item.arch}-common"]
  contexts = dependencies(item.image, item.arch)
  cache-from = cacheFrom(item.image, item.arch)
  cache-to = cacheTo(item.image, item.arch)
  tags = tags(item.image, item.arch)
}
IMAGES = [
  "scyllaridae-whisper",
  "scyllaridae-tn-zip",
  "scyllaridae-tn-warc",
  "scyllaridae-pandoc",
  "scyllaridae-openai-htr",
  "scyllaridae-scribe",
  "scyllaridae-ocrpdf",
  "scyllaridae-libreoffice",
  "scyllaridae-hls",
  "scyllaridae-coverpage",
  "scyllaridae-cleanpdf",
  "python3-13",
  "python3-14",
  "actions-runner",
  "archivesspace",
  "archivesspace-solr",
  "base",
  "crayfits",
  "drupal-php83",
  "drupal-php84",
  "go1-26",
  "homarus",
  "houdini",
  "hypercube",
  "islandora-php83",
  "islandora-php84",
  "java17",
  "java21",
  "java25",
  "leptonica",
  "mariadb11",
  "mergepdf",
  "nginx-php83",
  "nginx-php84",
  "ojs-php83",
  "ojs-php84",
  "omeka-classic-php83",
  "omeka-classic-php84",
  "omeka-s-php83",
  "omeka-s-php84",
  "php83",
  "php84",
  "scyllaridae",
  "solr9",
  "solr10",
  "tomcat9",
  "tomcat11",
  "wp-php83",
  "wp-php84",
]

PUBLISHED_IMAGES = {
  "scyllaridae-whisper" = "scyllaridae-whisper"
  "scyllaridae-tn-zip" = "scyllaridae-tn-zip"
  "scyllaridae-tn-warc" = "scyllaridae-tn-warc"
  "scyllaridae-pandoc" = "scyllaridae-pandoc"
  "scyllaridae-openai-htr" = "scyllaridae-openai-htr"
  "scyllaridae-scribe" = "scyllaridae-scribe"
  "scyllaridae-ocrpdf" = "scyllaridae-ocrpdf"
  "scyllaridae-libreoffice" = "scyllaridae-libreoffice"
  "scyllaridae-hls" = "scyllaridae-hls"
  "scyllaridae-coverpage" = "scyllaridae-coverpage"
  "scyllaridae-cleanpdf" = "scyllaridae-cleanpdf"
  "python3-13" = "python3.13"
  "python3-14" = "python3.14"
  "actions-runner" = "actions-runner"
  "archivesspace" = "archivesspace"
  "archivesspace-solr" = "archivesspace-solr"
  "base" = "base"
  "crayfits" = "crayfits"
  "drupal-php83" = "drupal"
  "drupal-php84" = "drupal"
  "go1-26" = "go"
  "homarus" = "homarus"
  "houdini" = "houdini"
  "hypercube" = "hypercube"
  "islandora-php83" = "islandora"
  "islandora-php84" = "islandora"
  "java17" = "java"
  "java21" = "java"
  "java25" = "java"
  "leptonica" = "leptonica"
  "mariadb11" = "mariadb"
  "mergepdf" = "mergepdf"
  "nginx-php83" = "nginx"
  "nginx-php84" = "nginx"
  "ojs-php83" = "ojs"
  "ojs-php84" = "ojs"
  "omeka-classic-php83" = "omeka-classic"
  "omeka-classic-php84" = "omeka-classic"
  "omeka-s-php83" = "omeka-s"
  "omeka-s-php84" = "omeka-s"
  "php83" = "php"
  "php84" = "php"
  "scyllaridae" = "scyllaridae"
  "solr9" = "solr"
  "solr10" = "solr"
  "tomcat9" = "tomcat"
  "tomcat11" = "tomcat"
  "wp-php83" = "wp"
  "wp-php84" = "wp"
}

LOCAL_TAG_SUFFIXES = {
  "scyllaridae-whisper" = ""
  "scyllaridae-tn-zip" = ""
  "scyllaridae-tn-warc" = ""
  "scyllaridae-pandoc" = ""
  "scyllaridae-openai-htr" = ""
  "scyllaridae-scribe" = ""
  "scyllaridae-ocrpdf" = ""
  "scyllaridae-libreoffice" = ""
  "scyllaridae-hls" = ""
  "scyllaridae-coverpage" = ""
  "scyllaridae-cleanpdf" = ""
  "python3-13" = ""
  "python3-14" = ""
  "actions-runner" = ""
  "archivesspace" = ""
  "archivesspace-solr" = ""
  "base" = ""
  "crayfits" = ""
  "drupal-php83" = "php83"
  "drupal-php84" = "php84"
  "go1-26" = "1.26"
  "homarus" = ""
  "houdini" = ""
  "hypercube" = ""
  "islandora-php83" = "php83"
  "islandora-php84" = "php84"
  "java17" = "17"
  "java21" = "21"
  "java25" = "25"
  "leptonica" = ""
  "mariadb11" = "11"
  "mergepdf" = ""
  "nginx-php83" = "php83"
  "nginx-php84" = "php84"
  "ojs-php83" = "php83"
  "ojs-php84" = "php84"
  "omeka-classic-php83" = "php83"
  "omeka-classic-php84" = "php84"
  "omeka-s-php83" = "php83"
  "omeka-s-php84" = "php84"
  "php83" = "8.3"
  "php84" = "8.4"
  "scyllaridae" = ""
  "solr9" = "9"
  "solr10" = "10"
  "tomcat9" = "9"
  "tomcat11" = "11"
  "wp-php83" = "php83"
  "wp-php84" = "php84"
}

DEPENDENCIES = {
  "scyllaridae-whisper" = ["scyllaridae"]
  "scyllaridae-tn-zip" = ["scyllaridae"]
  "scyllaridae-tn-warc" = ["scyllaridae"]
  "scyllaridae-pandoc" = ["scyllaridae"]
  "scyllaridae-openai-htr" = ["scyllaridae"]
  "scyllaridae-scribe" = ["scyllaridae"]
  "scyllaridae-ocrpdf" = ["scyllaridae", "leptonica"]
  "scyllaridae-libreoffice" = ["scyllaridae"]
  "scyllaridae-hls" = ["scyllaridae"]
  "scyllaridae-coverpage" = ["scyllaridae"]
  "scyllaridae-cleanpdf" = ["scyllaridae"]
  "python3-13" = ["base"]
  "python3-14" = ["base"]
  "actions-runner" = []
  "archivesspace" = ["java17", "archivesspace-solr"]
  "archivesspace-solr" = ["solr9"]
  "base" = []
  "crayfits" = ["scyllaridae"]
  "drupal-php83" = ["nginx-php83"]
  "drupal-php84" = ["nginx-php84"]
  "go1-26" = ["base"]
  "homarus" = ["scyllaridae"]
  "houdini" = ["scyllaridae"]
  "hypercube" = ["scyllaridae", "leptonica"]
  "islandora-php83" = ["drupal-php83"]
  "islandora-php84" = ["drupal-php84"]
  "java17" = ["base"]
  "java21" = ["base"]
  "java25" = ["base"]
  "leptonica" = []
  "mariadb11" = ["base"]
  "mergepdf" = ["scyllaridae", "leptonica"]
  "nginx-php83" = ["php83"]
  "nginx-php84" = ["php84"]
  "ojs-php83" = ["nginx-php83"]
  "ojs-php84" = ["nginx-php84"]
  "omeka-classic-php83" = ["nginx-php83"]
  "omeka-classic-php84" = ["nginx-php84"]
  "omeka-s-php83" = ["nginx-php83"]
  "omeka-s-php84" = ["nginx-php84"]
  "php83" = ["base"]
  "php84" = ["base"]
  "scyllaridae" = ["base", "go1-26"]
  "solr9" = ["java17"]
  "solr10" = ["java25"]
  "tomcat9" = ["java17"]
  "tomcat11" = ["java25"]
  "wp-php83" = ["nginx-php83"]
  "wp-php84" = ["nginx-php84"]
}

###############################################################################
# Variables
###############################################################################
variable "REPOSITORY" {
  default = "lehighlts"
}

variable "CACHE_FROM_REPOSITORY" {
  default = "lehighlts"
}

variable "CACHE_TO_REPOSITORY" {
  default = "lehighlts"
}

variable "TAGS" {
  # "latest" is reserved for the most recent release.
  # "local" is to distinguish that from builds produced locally.
  # Multiple tags can be specified by using a space " " delimited list.
  default = "local"
}

variable "SOURCE_DATE_EPOCH" {
  default = "0"
}

variable "BRANCH" {
  # Must be specified for ci builds.
  # BRANCH=$(git rev-parse --abbrev-ref HEAD)
  default = ""
}

variable "BASE_NO_CACHE" {
  # The published base image must resolve the current Alpine package index on
  # every CI rebuild. Otherwise BuildKit can indefinitely reuse an apk layer
  # after security fixes become available upstream.
  default = false
}

###############################################################################
# Functions
###############################################################################
function hostArch {
  params = []
  result = equal("linux/amd64", BAKE_LOCAL_PLATFORM) ? "amd64" : "arm64" # Only two platforms supported.
}

function imageArches {
  params = [image]
  result = image == "scyllaridae-whisper" ? ["amd64"] : ARCHES
}

function arches {
  params = [image, suffix]
  result = equal("", suffix) ? [for arch in imageArches(image): "${image}-${arch}" ] : [ for arch in imageArches(image): "${image}-${arch}-${suffix}" ]
}

function dependencies {
  params = [image, suffix]
  result = { for target in DEPENDENCIES[image]: target => notequal("", suffix) ? "target:${target}-${suffix}" : "target:${target}" }
}

function targets {
  params = [suffix]
  result = [for target in IMAGES: "${target}-${suffix}" if contains(imageArches(target), suffix)]
}

function "tagName" {
  params = [image, tag]
  result = equal("local", tag) && notequal("", LOCAL_TAG_SUFFIXES[image]) ? "${tag}-${LOCAL_TAG_SUFFIXES[image]}" : tag
}

function "tags" {
  params = [image, suffix]
  result = equal("", suffix) ? [for tag in split(" ", TAGS): "${REPOSITORY}/${PUBLISHED_IMAGES[image]}:${tagName(image, tag)}"] : [for tag in split(" ", TAGS): "${REPOSITORY}/${PUBLISHED_IMAGES[image]}:${tagName(image, tag)}-${suffix}"]
}

function "normalizeTag" {
  params = [value]
  result = trim(regex_replace(value, "[^A-Za-z0-9_.-]+", "-"), "-")
}

function "cacheFrom" {
  params = [image, arch]
  result = equal("", arch) ? [] : ["type=registry,ref=${CACHE_FROM_REPOSITORY}/cache:${image}-main-${arch}", notequal("", normalizeTag(BRANCH)) ? "type=registry,ref=${CACHE_FROM_REPOSITORY}/cache:${image}-${normalizeTag(BRANCH)}-${arch}" : ""]
}

function "cacheTo" {
  params = [image, arch]
  result = [notequal("", normalizeTag(BRANCH)) ? "type=registry,oci-mediatypes=true,mode=max,compression=estargz,compression-level=5,ref=${CACHE_TO_REPOSITORY}/cache:${image}-${normalizeTag(BRANCH)}-${arch}" : ""]
}

function "context" {
  params = [image]
  result = "images/${image}"
}

###############################################################################
# Groups
###############################################################################
group "default" {
  targets = IMAGES
}

group "amd64" {
  targets = targets("amd64")
}

group "arm64" {
  targets = targets("arm64")
}

###############################################################################
# Common target properties.
###############################################################################
target "common" {
  args = {
    # Required for reproducible builds.
    # Requires Buildkit 0.11+
    # See: https://reproducible-builds.org/docs/source-date-epoch/
    SOURCE_DATE_EPOCH = "${SOURCE_DATE_EPOCH}",
  }
  labels = {
    "org.opencontainers.image.url" = "https://github.com/lehigh-university-libraries/buildkit/"
    "org.opencontainers.image.source" = "https://github.com/lehigh-university-libraries/buildkit/"
  }
}

target "amd64-common" {
  platforms = ["linux/amd64"]
}

target "arm64-common" {
  platforms = ["linux/arm64"]
}

###############################################################################
# Image specific target properties.
###############################################################################
target "archivesspace-common" {
  inherits = ["common"]
  context = context("archivesspace")
}

target "archivesspace-solr-common" {
  inherits = ["common"]
  context = context("archivesspace-solr")
}

target "base-common" {
  inherits = ["common"]
  context = context("base")
  no-cache = BASE_NO_CACHE
  contexts = {
    # The digest (sha256 hash) is not platform specific but the digest for the manifest of all platforms.
    # It will be the digest printed when you do: docker pull alpine:3.17.1
    # Not the one displayed on DockerHub.
    alpine = "docker-image://alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b"
  }
}

target "crayfits-common" {
  inherits = ["common"]
  context = context("crayfits")
}

target "drupal-php83-common" {
  inherits = ["common"]
  context = context("drupal")
  args = {
    PHP_BASE = "nginx-php83"
  }
}

target "drupal-php84-common" {
  inherits = ["common"]
  context = context("drupal")
  args = {
    PHP_BASE = "nginx-php84"
  }
}

target "go1-26-common" {
  inherits = ["common"]
  context = context("go1-26")
}

target "homarus-common" {
  inherits = ["common"]
  context = context("homarus")
}

target "houdini-common" {
  inherits = ["common"]
  context = context("houdini")
}

target "hypercube-common" {
  inherits = ["common"]
  context = context("hypercube")
}

target "islandora-php83-common" {
  inherits = ["common"]
  context = context("islandora")
  args = {
    DRUPAL_BASE = "drupal-php83"
  }
}

target "islandora-php84-common" {
  inherits = ["common"]
  context = context("islandora")
  args = {
    DRUPAL_BASE = "drupal-php84"
  }
}

target "java17-common" {
  inherits = ["common"]
  context = context("java17")
}

target "java21-common" {
  inherits = ["common"]
  context = context("java21")
}

target "java25-common" {
  inherits = ["common"]
  context = context("java25")
}

target "leptonica-common" {
  inherits = ["common"]
  context = context("leptonica")
  contexts = {
    # The digest (sha256 hash) is not platform specific but the digest for the manifest of all platforms.
    # It will be the digest printed when you do: docker pull alpine:3.17.1
    # Not the one displayed on DockerHub.
    alpine = "docker-image://alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b"
  }
}

target "mariadb11-common" {
  inherits = ["common"]
  context = context("mariadb11")
}

target "mergepdf-common" {
  inherits = ["common"]
  context = context("mergepdf")
}

target "nginx-php83-common" {
  inherits = ["common"]
  context = context("nginx")
  args = {
    PHP_BASE = "php83"
  }
}

target "nginx-php84-common" {
  inherits = ["common"]
  context = context("nginx")
  args = {
    PHP_BASE = "php84"
  }
}

target "ojs-php83-common" {
  inherits = ["common"]
  context = context("ojs")
  args = {
    PHP_BASE = "nginx-php83"
    PHP_PACKAGE = "php83"
  }
}

target "ojs-php84-common" {
  inherits = ["common"]
  context = context("ojs")
  args = {
    PHP_BASE = "nginx-php84"
    PHP_PACKAGE = "php84"
  }
}

target "omeka-classic-php83-common" {
  inherits = ["common"]
  context = context("omeka-classic")
  args = {
    PHP_BASE = "nginx-php83"
    PHP_PACKAGE = "php83"
  }
}

target "omeka-classic-php84-common" {
  inherits = ["common"]
  context = context("omeka-classic")
  args = {
    PHP_BASE = "nginx-php84"
    PHP_PACKAGE = "php84"
  }
}

target "omeka-s-php83-common" {
  inherits = ["common"]
  context = context("omeka-s")
  args = {
    PHP_BASE = "nginx-php83"
  }
}

target "omeka-s-php84-common" {
  inherits = ["common"]
  context = context("omeka-s")
  args = {
    PHP_BASE = "nginx-php84"
  }
}

target "php83-common" {
  inherits = ["common"]
  context = context("php83")
}

target "php84-common" {
  inherits = ["common"]
  context = context("php84")
}

target "scyllaridae-common" {
  inherits = ["common"]
  context = context("scyllaridae")
}

target "solr9-common" {
  inherits = ["common"]
  context = context("solr9")
}

target "solr10-common" {
  inherits = ["common"]
  context = context("solr10")
}

target "tomcat9-common" {
  inherits = ["common"]
  context = context("tomcat9")
}

target "tomcat11-common" {
  inherits = ["common"]
  context = context("tomcat11")
}

target "wp-php83-common" {
  inherits = ["common"]
  context = context("wp")
  args = {
    PHP_BASE = "nginx-php83"
  }
}

target "wp-php84-common" {
  inherits = ["common"]
  context = context("wp")
  args = {
    PHP_BASE = "nginx-php84"
  }
}

###############################################################################

target "actions-runner-common" {
  inherits = ["common"]
  context = context("actions-runner")
}

target "python3-13-common" {
  inherits = ["common"]
  context = context("python3-13")
}

target "python3-14-common" {
  inherits = ["common"]
  context = context("python3-14")
}

target "scyllaridae-cleanpdf-common" {
  inherits = ["common"]
  context = context("scyllaridae-cleanpdf")
}

target "scyllaridae-coverpage-common" {
  inherits = ["common"]
  context = context("scyllaridae-coverpage")
}

target "scyllaridae-hls-common" {
  inherits = ["common"]
  context = context("scyllaridae-hls")
}

target "scyllaridae-libreoffice-common" {
  inherits = ["common"]
  context = context("scyllaridae-libreoffice")
}

target "scyllaridae-ocrpdf-common" {
  inherits = ["common"]
  context = context("scyllaridae-ocrpdf")
}

target "scyllaridae-openai-htr-common" {
  inherits = ["common"]
  context = context("scyllaridae-openai-htr")
}

target "scyllaridae-scribe-common" {
  inherits = ["common"]
  context = context("scyllaridae-scribe")
}

target "scyllaridae-pandoc-common" {
  inherits = ["common"]
  context = context("scyllaridae-pandoc")
}

target "scyllaridae-tn-warc-common" {
  inherits = ["common"]
  context = context("scyllaridae-tn-warc")
}

target "scyllaridae-tn-zip-common" {
  inherits = ["common"]
  context = context("scyllaridae-tn-zip")
}

target "scyllaridae-whisper-common" {
  inherits = ["common"]
  context = context("scyllaridae-whisper")
  platforms = ["linux/amd64"]
}
