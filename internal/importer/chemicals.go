package importer

import (
	"fmt"
	"regexp"
	"strings"
)

// chemicalsImporter wires the chemicals module. Target fields focus on
// identification + commonly-known physical properties + a handful of
// high-signal GHS flags; the per-record detail form is the right surface
// for the full 20-odd hazard checkboxes.
type chemicalsImporter struct{}

func init() {
	Register(&chemicalsImporter{})
}

func (*chemicalsImporter) ModuleSlug() string { return "chemicals" }

func (*chemicalsImporter) TargetFields() []TargetField {
	return []TargetField{
		{Name: "product_name", Label: "Product Name", Required: true, Aliases: []string{"name", "product", "trade name", "chemical name"}},
		{Name: "manufacturer", Label: "Manufacturer", Aliases: []string{"mfr", "maker", "supplier", "vendor"}},
		{Name: "manufacturer_phone", Label: "Manufacturer Phone", Aliases: []string{"mfr phone", "supplier phone", "contact phone"}},
		{Name: "primary_cas_number", Label: "Primary CAS Number", Aliases: []string{"cas", "cas number", "cas no", "cas #"}, Description: "CAS registry number in 7432-##-# or similar form."},
		{Name: "signal_word", Label: "GHS Signal Word", Aliases: []string{"signal", "ghs signal"}, Description: "Danger or Warning."},
		{Name: "physical_state", Label: "Physical State", Aliases: []string{"state", "form", "phase"}, Description: "solid, liquid, or gas."},
		{Name: "flash_point_f", Label: "Flash Point (°F)", Aliases: []string{"flash pt", "flash point"}},
		{Name: "ph", Label: "pH", Aliases: []string{"ph value"}},
		{Name: "appearance", Label: "Appearance", Aliases: []string{"color", "description", "visual"}},
		{Name: "odor", Label: "Odor", Aliases: []string{"smell"}},
		{Name: "is_flammable", Label: "Flammable?", Aliases: []string{"flammable", "is flammable"}, Description: "Y/N, true/false, or 1/0."},
		{Name: "is_carcinogen", Label: "Carcinogen?", Aliases: []string{"carcinogen", "carc"}},
		{Name: "is_corrosive_to_metal", Label: "Corrosive to Metal?", Aliases: []string{"corrosive", "metal corrosive"}},
	}
}

type chemicalPayload struct {
	EstablishmentID     int64
	ProductName         string
	Manufacturer        *string
	ManufacturerPhone   *string
	PrimaryCAS          *string
	SignalWord          *string
	PhysicalState       *string
	FlashPointF         *float64
	PH                  *float64
	Appearance          *string
	Odor                *string
	IsFlammable         int
	IsCarcinogen        int
	IsCorrosiveToMetal  int
}

func (*chemicalsImporter) ValidateRow(
	raw map[string]string,
	mapping map[string]string,
	rowIdx int,
	ctx RowContext,
) (any, []ValidationError) {
	var errs []ValidationError
	if ctx.EstablishmentID == nil {
		errs = append(errs, ValidationError{Row: rowIdx, Message: "target establishment not set on the import"})
		return nil, errs
	}

	resolve := func(target string) string {
		for src, dst := range mapping {
			if dst == target {
				return strings.TrimSpace(raw[src])
			}
		}
		return ""
	}

	productName := resolve("product_name")
	if productName == "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "product_name", Message: "Product Name is required"})
	}

	p := &chemicalPayload{
		EstablishmentID: *ctx.EstablishmentID,
		ProductName:     productName,
	}

	setIfNonEmpty(&p.Manufacturer, resolve("manufacturer"))
	setIfNonEmpty(&p.ManufacturerPhone, resolve("manufacturer_phone"))
	setIfNonEmpty(&p.Appearance, resolve("appearance"))
	setIfNonEmpty(&p.Odor, resolve("odor"))

	if v := resolve("primary_cas_number"); v != "" {
		if !casPattern.MatchString(v) {
			errs = append(errs, ValidationError{Row: rowIdx, Column: "primary_cas_number", Message: "CAS number must look like 1-7 digits, 2 digits, 1 digit (e.g. 7432-18-8)"})
		} else {
			p.PrimaryCAS = &v
		}
	}

	if v := resolve("signal_word"); v != "" {
		switch strings.ToLower(v) {
		case "danger":
			norm := "Danger"
			p.SignalWord = &norm
		case "warning":
			norm := "Warning"
			p.SignalWord = &norm
		default:
			errs = append(errs, ValidationError{Row: rowIdx, Column: "signal_word", Message: "Signal word must be Danger or Warning"})
		}
	}

	if v := resolve("physical_state"); v != "" {
		lower := strings.ToLower(v)
		switch lower {
		case "solid", "liquid", "gas":
			p.PhysicalState = &lower
		default:
			errs = append(errs, ValidationError{Row: rowIdx, Column: "physical_state", Message: "Physical state must be solid, liquid, or gas"})
		}
	}

	if v, ok, msg := parseFloat(resolve("flash_point_f")); msg != "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "flash_point_f", Message: msg})
	} else if ok {
		p.FlashPointF = &v
	}
	if v, ok, msg := parseFloat(resolve("ph")); msg != "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "ph", Message: msg})
	} else if ok {
		if v < 0 || v > 14 {
			errs = append(errs, ValidationError{Row: rowIdx, Column: "ph", Message: "pH must be between 0 and 14"})
		} else {
			p.PH = &v
		}
	}

	if b, ok, msg := parseBool(resolve("is_flammable")); msg != "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "is_flammable", Message: msg})
	} else if ok && b {
		p.IsFlammable = 1
	}
	if b, ok, msg := parseBool(resolve("is_carcinogen")); msg != "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "is_carcinogen", Message: msg})
	} else if ok && b {
		p.IsCarcinogen = 1
	}
	if b, ok, msg := parseBool(resolve("is_corrosive_to_metal")); msg != "" {
		errs = append(errs, ValidationError{Row: rowIdx, Column: "is_corrosive_to_metal", Message: msg})
	} else if ok && b {
		p.IsCorrosiveToMetal = 1
	}

	if len(errs) > 0 {
		return nil, errs
	}
	return p, nil
}

func (*chemicalsImporter) InsertRow(db Execer, payload any, ctx RowContext) (int64, error) {
	p, ok := payload.(*chemicalPayload)
	if !ok {
		return 0, fmt.Errorf("chemicals: wrong payload type %T", payload)
	}
	if err := db.ExecParams(
		`INSERT INTO chemicals (
		     establishment_id, product_name, manufacturer, manufacturer_phone,
		     primary_cas_number, signal_word,
		     physical_state, flash_point_f, ph, appearance, odor,
		     is_flammable, is_carcinogen, is_corrosive_to_metal)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		p.EstablishmentID, p.ProductName, p.Manufacturer, p.ManufacturerPhone,
		p.PrimaryCAS, p.SignalWord,
		p.PhysicalState, p.FlashPointF, p.PH, p.Appearance, p.Odor,
		p.IsFlammable, p.IsCarcinogen, p.IsCorrosiveToMetal,
	); err != nil {
		return 0, err
	}
	id, err := db.QueryVal("SELECT last_insert_rowid()")
	if err != nil {
		return 0, err
	}
	return id.(int64), nil
}

// ---- helpers shared across mappers ---------------------------------------

var casPattern = regexp.MustCompile(`^\d{1,7}-\d{2}-\d$`)

// parseFloat returns (value, true, "") on success, ("", false, "") if the
// input is blank, and ("", false, error-message) on failure.
func parseFloat(v string) (float64, bool, string) {
	v = strings.TrimSpace(v)
	if v == "" {
		return 0, false, ""
	}
	var f float64
	if _, err := fmt.Sscanf(v, "%f", &f); err != nil {
		return 0, false, fmt.Sprintf("%q is not a number", v)
	}
	return f, true, ""
}

// parseBool accepts common boolean spellings. Returns (value, true, "")
// on success, (false, false, "") if blank, (false, false, error) otherwise.
func parseBool(v string) (bool, bool, string) {
	v = strings.TrimSpace(v)
	if v == "" {
		return false, false, ""
	}
	switch strings.ToLower(v) {
	case "1", "y", "yes", "true", "t", "x", "✓":
		return true, true, ""
	case "0", "n", "no", "false", "f", "":
		return false, true, ""
	}
	return false, false, fmt.Sprintf("%q is not a boolean (try Y/N, true/false, or 1/0)", v)
}
