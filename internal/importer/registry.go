package importer

import "sort"

// registry is the in-process catalog of module slug -> Importer. Populated
// at package init time by each mapper's init() function.
var registry = map[string]Importer{}

// Register adds an importer to the registry. Intended for init() use;
// a second registration under the same slug panics so test + prod can't
// disagree on module shapes.
func Register(imp Importer) {
	slug := imp.ModuleSlug()
	if _, exists := registry[slug]; exists {
		panic("importer: module already registered: " + slug)
	}
	registry[slug] = imp
}

// Get returns the importer for a module slug, or (nil, false) if none.
func Get(slug string) (Importer, bool) {
	imp, ok := registry[slug]
	return imp, ok
}

// Modules returns the sorted list of registered module slugs. Used by the
// admin UI's module picker.
func Modules() []string {
	out := make([]string, 0, len(registry))
	for slug := range registry {
		out = append(out, slug)
	}
	sort.Strings(out)
	return out
}
