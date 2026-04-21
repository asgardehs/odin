// Shared TS types for the admin import flow. Mirror the Go structs in
// internal/importer / internal/server/api_import.go so the compile-time
// types and the wire format can't drift silently.

export interface ImportTargetField {
  name: string;
  label: string;
  required?: boolean;
  aliases?: string[];
  description?: string;
}

export interface ImportModuleDescriptor {
  slug: string;
  label: string;
  target_fields: ImportTargetField[];
}

export interface ImportValidationError {
  row: number;
  column: string;
  message: string;
}

export interface ImportPreview {
  token: string;
  module: string;
  status: 'pending' | 'committed' | 'discarded' | 'expired';
  headers: string[];
  mapping_suggestions: Record<string, string>;
  mapping: Record<string, string>;
  row_count: number;
  rows_preview: Record<string, string>[];
  validation_errors: ImportValidationError[];
  target_fields: ImportTargetField[];
  uploaded_at: string;
  expires_at: string;
}

export interface ImportCommitResult {
  token: string;
  module: string;
  inserted_count: number;
  skipped_count: number;
  committed_at: string;
  audit_summary: string;
}

/** Sentinel value that marks a source column as deliberately unmapped. */
export const IMPORT_IGNORE_MARKER = '__ignore__';
