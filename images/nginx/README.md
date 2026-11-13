# Shared Nginx image

Application images inherit Nginx, its s6 service, and confd-generated settings
from this image. Every application server must retain
`include /etc/nginx/shared/fpm.conf;`; it supplies internal health probes and the
reserved Google Search Console verification location.

`/google204a4e549d4da46a.html` serves the image-owned file under
`/usr/local/share/nginx/verification/`, independently of the application document
root. The exact-match location takes precedence over application prefix and
regex locations. Keep this shared configuration out of application override
files; overriding the same exact location causes a configuration error rather
than silently replacing it. The default server also includes it.

An ingress proxy still runs before Nginx. For captcha-protect, exclude only this
verification path from challenges:

```yaml
excludeRoutes: ['^/google204a4e549d4da46a\.html$']
```

Check the public HTTPS URL returns 200 and the original verification body without
a login, CAPTCHA challenge, or application redirect before verifying a property
in Search Console. Existing deployments need rebuilt descendant images and new
published digest pins; changing this base image does not alter running images.

The `GoogleSiteVerification` test checks the base default server and a replacement
application server with a different root, an HTML-denying regex, and a catch-all
route, ensuring the reserved exact path still serves the original bytes.
