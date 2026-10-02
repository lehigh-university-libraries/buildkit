from warcio.archiveiterator import ArchiveIterator
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
import tempfile
import os
import sys


for record in ArchiveIterator(sys.stdin.buffer):
    if record.rec_type != "response":
        continue
    url = record.rec_headers.get_header("WARC-Target-URI")
    if not url or not url.endswith("/"):
        continue

    html_content = record.content_stream().read().decode("utf-8")
    with tempfile.NamedTemporaryFile(mode="w", suffix=".html", delete=False) as f:
        f.write(html_content)
        temp_file = f.name

    options = Options()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--disable-extensions")
    options.add_argument("--disable-background-timer-throttling")
    options.add_argument("--disable-backgrounding-occluded-windows")
    options.add_argument("--disable-renderer-backgrounding")

    options.binary_location = "/usr/bin/chromium-browser"

    service = Service(executable_path="/usr/bin/chromedriver")

    driver = webdriver.Chrome(service=service, options=options)
    driver.set_window_size(750, 750)
    driver.get(f"file://{temp_file}")

    screenshot_file = tempfile.mktemp(suffix=".png")
    driver.save_screenshot(screenshot_file)
    driver.quit()

    with open(screenshot_file, "rb") as img_file:
        sys.stdout.buffer.write(img_file.read())

    os.unlink(temp_file)
    os.unlink(screenshot_file)
    break
