# Security Policy

This policy applies to every public Asgard EHS repository:
[Odin](https://github.com/asgardehs/odin),
[Heimdall](https://github.com/asgardehs/heimdall), and
[Ratatoskr](https://github.com/asgardehs/ratatoskr).

## Reporting a Vulnerability

Email **[asgardehs@proton.me](mailto:asgardehs@proton.me)** with the word
**SECURITY** in the subject line. Do not open a public GitHub issue for
security reports — issues are world-readable from the moment they're filed.

For sensitive findings, encrypt your message with the project's PGP key.
The fingerprint is:

```
B38E E5D8 26C3 2451 79EC  1191 A91B 7835 538F 03C3
```

Import it from a public keyserver:

```bash
gpg --recv-keys A91B7835538F03C3
```

The full ASCII-armored public key is published at the [bottom of this
page](#public-key) and on the
[developer page](https://asgardehs.github.io/developer/#verifying-commits).

### What to Include

Reports are easier to triage when they include:

1. Your name and affiliation, if you'd like to be credited in the advisory.
2. The repository and version — a commit hash or release tag — where you
   found the issue.
3. A description of the vulnerability and its scope: who could exploit
   it, and under what conditions.
4. Steps to reproduce. We need to see the issue ourselves before we can
   fix it.
5. An attack scenario, if one isn't obvious from the reproduction steps.

## What Happens Next

Asgard EHS is a solo-maintained project. The [Code of Conduct already
acknowledges this](https://asgardehs.github.io/code-of-conduct/#moderation),
and the security process inherits the same constraint. The targets below
are commitments, not guarantees — we will say so honestly if we miss them.

- **Acknowledgement within 7 days** of the report landing in our inbox.
- **Triage update within 48 hours of acknowledgement** describing whether
  we can reproduce the issue, the affected versions, and our intended
  response.
- **Ongoing updates** as we audit related code, prepare fixes, and
  schedule a coordinated disclosure.

If a report sits without acknowledgement past 7 days, please assume the
email did not arrive. Resend, or open a non-detail-leaking GitHub issue
asking us to check our inbox.

## Disclosure

We follow the [OWASP Vulnerability Disclosure Cheat
Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Vulnerability_Disclosure_Cheat_Sheet.html)
as the reference for coordinated disclosure. The default posture is:

- Confirm and reproduce the issue privately.
- Audit related code paths for similar problems.
- Prepare patches across maintained release branches.
- Publish the fix and a security advisory at the same time, crediting
  the reporter unless they prefer to remain anonymous.
- Record the advisory in the
  [project changelog](https://github.com/asgardehs/asgardehs.github.io/blob/main/CHANGELOG.md).

For vulnerabilities in third-party dependencies, please report to the
upstream maintainer. We will coordinate with upstream on issues that
affect Asgard EHS users.

## Scope

This policy covers code, configuration, and documentation in the public
Asgard EHS repositories. It does not cover:

- Third-party dependencies — report to the upstream project.
- Forks or derivative projects — report to that project's maintainer.
- Issues that require physical access to the user's machine. The
  applications are local-first by design; an attacker who already has
  the device has bypassed the threat model.

## Public Key

```
-----BEGIN PGP PUBLIC KEY BLOCK-----

mDMEaerH/BYJKwYBBAHaRw8BAQdAH1lC3Y8WwpqfKsdRt1h2e0r+91pG2Jc2jYfr
b5kUsZe0IEFkYW0gSi4gQmljayA8YWRhbS5iaWNrODZAcG0ubWU+iJYEExYKAD4W
IQSzjuXYJsMkUXnsEZGpG3g1U48DwwUCaerH/AIbAwUJCWYBgAULCQgHAgYVCgkI
CwIEFgIDAQIeAQIXgAAKCRCpG3g1U48DwxsSAQCpvHf2zsAYnQ8h5MxZPRdbV7xr
/6DcU6wQUCSvsqJLFAD+KhtfR8Vm/IUvCTVRNHWQ53kVgwQbavOSMXlM5+W9XgG4
OARp6sf8EgorBgEEAZdVAQUBAQdAxd1SqGGETXiR1LqqXQTaI8Rhz44iFSE9dHWB
E8rZf3cDAQgHiH4EGBYKACYWIQSzjuXYJsMkUXnsEZGpG3g1U48DwwUCaerH/AIb
DAUJCWYBgAAKCRCpG3g1U48Dw5lrAPwJTvohqhrOZWxWmwg5lUUIabgfk6TRl1f1
uw7MpAxXlQD/XuZFKLXG49RUYCvi6/Ochd5GLIEpzDVR+yU6MFD0wAI=
=V3xL
-----END PGP PUBLIC KEY BLOCK-----
```

---

**Version 0.1.0.** Tracked semantically: major bumps for contact-info or
process changes that break expectations; minor for additions; patch for
typos. Material changes recorded in the
[project changelog](https://github.com/asgardehs/asgardehs.github.io/blob/main/CHANGELOG.md).
