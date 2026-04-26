# Repository Pattern

One `XxxInput` struct per entity, shared by Create + Update. Nullable
columns are pointers (`*string`, `*int`); NOT NULL columns are values.
SQL stays raw inside method bodies.

```go
type EstablishmentInput struct {
    Name          string  `json:"name"`                       // NOT NULL
    NAICSCode    *string  `json:"naics_code,omitempty"`        // nullable
    PeakEmployees *int    `json:"peak_employees,omitempty"`
}

func (r *Repo) CreateEstablishment(user string, in EstablishmentInput) (int64, error) {
    return r.insertAndAudit(establishmentTable, establishmentModule, user,
        fmt.Sprintf("Created establishment: %s", in.Name),
        `INSERT INTO establishments (name, naics_code, peak_employees)
         VALUES (?, ?, ?)`,
        in.Name, in.NAICSCode, in.PeakEmployees,
    )
}
```

Rules:

- Single `*Input` struct shared by Create + Update. Pointer-to-optional
  distinguishes "field not provided" from "field set to zero."
- Mutations route through `insertAndAudit` / `updateAndAudit` /
  `deleteAndAudit`. Audit logging is automatic — never call
  `db.ExecParams` for mutations directly.
- No ORM, no query builder, no `sqlc`. Raw SQL stays in the method body.

**Why raw SQL:** zero-CGO builds via `ncruces/go-sqlite3` are non-negotiable
(cross-platform binaries build locally without CI runtime). Adding an ORM
layer reintroduces the abstraction tax we explicitly avoided, breaks the
"what's typed is what executes" readability win, and risks pulling in CGO
indirectly. Inline SQL keeps both the build pipeline and the source clean.
