# Crayfits

Docker image for [CrayFits]. [FITS][1] as a microservice.


Built from [lehigh-university-libraries/buildkit crayfits](https://github.com/lehigh-university-libraries/buildkit/tree/main/images/crayfits)

## Dependencies

Requires `lehighlts/scyllaridae` Docker image to build. Please refer to the
[Scyllaridae Image README](../scyllaridae/README.md) for additional information including
additional settings, volumes, ports, etc.

At runtime, set `CRAYFITS_WEBSERVICE_URI` to an externally managed FITS servlet.
This repository no longer builds a FITS servlet image.

## Settings

| Environment Variable    | Default                       | Description                                                                                       |
| :---------------------- | :---------------------------- | :------------------------------------------------------------------------------------------------ |
| CRAYFITS_WEBSERVICE_URI | http://fits:8080/fits/examine | The URL of the FITS servlet.                                                                      |

[1]: https://harvard-lts.github.io/fits/
