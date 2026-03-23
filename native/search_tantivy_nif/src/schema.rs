use rustler::ResourceArc;
use tantivy::schema::{self, Schema, SchemaBuilder, STORED, STRING};

use crate::error::TantivyNifError;
use crate::index::IndexResource;

/// A field definition: `(name, type_str, [(option_key, option_value)])`.
///
/// Option values are strings: "true"/"false" for booleans, or string values
/// like tokenizer names.
type FieldDef = (String, String, Vec<(String, String)>);

pub struct SchemaResource {
    pub schema: Schema,
}

impl std::panic::RefUnwindSafe for SchemaResource {}

#[rustler::resource_impl]
impl rustler::Resource for SchemaResource {}

/// Build a schema from field definitions.
///
/// Each field is `(name, type_str, [(option_key, option_value)])`.
#[rustler::nif]
fn schema_build(
    field_defs: Vec<FieldDef>,
) -> Result<ResourceArc<SchemaResource>, String> {
    crate::catch_nif_panic! {
        let schema = build_schema_internal(&field_defs).map_err(|e| e.to_string())?;
        Ok(ResourceArc::new(SchemaResource { schema }))
    }
}

fn opt_bool(options: &[(String, String)], key: &str) -> Option<bool> {
    options
        .iter()
        .find(|(k, _)| k == key)
        .map(|(_, v)| v == "true")
}

fn opt_str<'a>(options: &'a [(String, String)], key: &str) -> Option<&'a str> {
    options
        .iter()
        .find(|(k, _)| k == key)
        .map(|(_, v)| v.as_str())
}

fn build_schema_internal(
    field_defs: &[FieldDef],
) -> Result<Schema, TantivyNifError> {
    let mut builder = SchemaBuilder::default();

    for (name, field_type, options) in field_defs {
        let stored = opt_bool(options, "stored").unwrap_or(false);
        let indexed = opt_bool(options, "indexed").unwrap_or(true);
        let fast = opt_bool(options, "fast").unwrap_or(false);
        let tokenizer = opt_str(options, "tokenizer");

        match field_type.as_str() {
            "text" => {
                let tokenizer_name = tokenizer.unwrap_or("default");
                let indexing = schema::TextFieldIndexing::default()
                    .set_tokenizer(tokenizer_name)
                    .set_index_option(schema::IndexRecordOption::WithFreqsAndPositions);
                let mut opts = schema::TextOptions::default().set_indexing_options(indexing);
                if stored {
                    opts = opts.set_stored();
                }
                if fast {
                    opts = opts | schema::FAST;
                }
                builder.add_text_field(name, opts);
            }
            "string" => {
                let mut opts = if stored { STRING | STORED } else { STRING };
                if !indexed {
                    opts = if stored {
                        STORED.into()
                    } else {
                        return Err(TantivyNifError::Schema(format!(
                            "field '{}' must be stored or indexed",
                            name
                        )));
                    };
                }
                if fast {
                    opts = opts | schema::FAST;
                }
                builder.add_text_field(name, opts);
            }
            "u64" => {
                let mut opts = schema::NumericOptions::default();
                if stored {
                    opts = opts.set_stored();
                }
                if indexed {
                    opts = opts.set_indexed();
                }
                if fast {
                    opts = opts.set_fast();
                }
                builder.add_u64_field(name, opts);
            }
            "i64" => {
                let mut opts = schema::NumericOptions::default();
                if stored {
                    opts = opts.set_stored();
                }
                if indexed {
                    opts = opts.set_indexed();
                }
                if fast {
                    opts = opts.set_fast();
                }
                builder.add_i64_field(name, opts);
            }
            "f64" => {
                let mut opts = schema::NumericOptions::default();
                if stored {
                    opts = opts.set_stored();
                }
                if indexed {
                    opts = opts.set_indexed();
                }
                if fast {
                    opts = opts.set_fast();
                }
                builder.add_f64_field(name, opts);
            }
            "bool" => {
                let mut opts = schema::NumericOptions::default();
                if stored {
                    opts = opts.set_stored();
                }
                if indexed {
                    opts = opts.set_indexed();
                }
                if fast {
                    opts = opts.set_fast();
                }
                builder.add_bool_field(name, opts);
            }
            "date" => {
                let mut opts = schema::DateOptions::default();
                if stored {
                    opts = opts.set_stored();
                }
                if indexed {
                    opts = opts.set_indexed();
                }
                if fast {
                    opts = opts.set_fast();
                }
                builder.add_date_field(name, opts);
            }
            "bytes" => {
                let mut opts = schema::BytesOptions::default();
                if stored {
                    opts = opts.set_stored();
                }
                if indexed {
                    opts = opts.set_indexed();
                }
                if fast {
                    opts = opts.set_fast();
                }
                builder.add_bytes_field(name, opts);
            }
            "json" => {
                let opts = if stored {
                    schema::JsonObjectOptions::default()
                        .set_stored()
                        .set_indexing_options(
                            schema::TextFieldIndexing::default()
                                .set_tokenizer("default")
                                .set_index_option(schema::IndexRecordOption::WithFreqsAndPositions),
                        )
                } else {
                    schema::JsonObjectOptions::default().set_indexing_options(
                        schema::TextFieldIndexing::default()
                            .set_tokenizer("default")
                            .set_index_option(schema::IndexRecordOption::WithFreqsAndPositions),
                    )
                };
                builder.add_json_field(name, opts);
            }
            "ip_addr" => {
                let mut opts = schema::IpAddrOptions::default();
                if stored {
                    opts = opts.set_stored();
                }
                if indexed {
                    opts = opts.set_indexed();
                }
                if fast {
                    opts = opts.set_fast();
                }
                builder.add_ip_addr_field(name, opts);
            }
            "facet" => {
                let opts = if stored {
                    schema::FacetOptions::default().set_stored()
                } else {
                    schema::FacetOptions::default()
                };
                builder.add_facet_field(name, opts);
            }
            other => {
                return Err(TantivyNifError::Schema(format!(
                    "unknown field type: {}",
                    other
                )));
            }
        }
    }

    Ok(builder.build())
}

/// Check if a field exists in the schema.
#[rustler::nif]
fn schema_field_exists(
    index_res: ResourceArc<IndexResource>,
    field_name: String,
) -> Result<bool, String> {
    crate::catch_nif_panic! {
        Ok(index_res.schema.get_field(&field_name).is_ok())
    }
}

/// Get all field names from the schema.
#[rustler::nif]
fn schema_get_field_names(
    index_res: ResourceArc<IndexResource>,
) -> Result<Vec<String>, String> {
    crate::catch_nif_panic! {
        Ok(index_res
            .schema
            .fields()
            .map(|(_field, entry)| entry.name().to_string())
            .collect())
    }
}

/// Get the type of a field in the schema.
#[rustler::nif]
fn schema_get_field_type(
    index_res: ResourceArc<IndexResource>,
    field_name: String,
) -> Result<String, String> {
    crate::catch_nif_panic! {
        let field = index_res
            .schema
            .get_field(&field_name)
            .map_err(|_| format!("unknown field: {}", field_name))?;

        let entry = index_res.schema.get_field_entry(field);
        let type_name = match entry.field_type() {
            schema::FieldType::Str(opts) => {
                if opts.get_indexing_options().map_or(false, |idx| {
                    idx.index_option() == schema::IndexRecordOption::Basic
                }) {
                    "string"
                } else {
                    "text"
                }
            }
            schema::FieldType::U64(_) => "u64",
            schema::FieldType::I64(_) => "i64",
            schema::FieldType::F64(_) => "f64",
            schema::FieldType::Bool(_) => "bool",
            schema::FieldType::Date(_) => "date",
            schema::FieldType::Bytes(_) => "bytes",
            schema::FieldType::JsonObject(_) => "json",
            schema::FieldType::IpAddr(_) => "ip_addr",
            schema::FieldType::Facet(_) => "facet",
        };

        Ok(type_name.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_build_schema_text_stored() {
        let fields = vec![(
            "title".into(),
            "text".into(),
            vec![("stored".into(), "true".into())],
        )];
        let schema = build_schema_internal(&fields).unwrap();
        assert!(schema.get_field("title").is_ok());
    }

    #[test]
    fn test_build_schema_all_types() {
        let types = vec![
            "text", "string", "u64", "i64", "f64", "bool", "date", "bytes", "json", "ip_addr",
            "facet",
        ];
        let fields: Vec<_> = types
            .iter()
            .map(|t| {
                (
                    format!("field_{}", t),
                    t.to_string(),
                    vec![("stored".into(), "true".into())],
                )
            })
            .collect();
        let schema = build_schema_internal(&fields).unwrap();
        for t in types {
            assert!(
                schema.get_field(&format!("field_{}", t)).is_ok(),
                "field_{} should exist",
                t
            );
        }
    }

    #[test]
    fn test_build_schema_invalid_type() {
        let fields = vec![("bad".into(), "nonexistent".into(), vec![])];
        let result = build_schema_internal(&fields);
        assert!(result.is_err());
    }

    #[test]
    fn test_build_schema_with_tokenizer() {
        let fields = vec![(
            "body".into(),
            "text".into(),
            vec![
                ("stored".into(), "true".into()),
                ("tokenizer".into(), "en_stem".into()),
            ],
        )];
        let schema = build_schema_internal(&fields).unwrap();
        let field = schema.get_field("body").unwrap();
        let entry = schema.get_field_entry(field);
        match entry.field_type() {
            schema::FieldType::Str(opts) => {
                let indexing = opts.get_indexing_options().unwrap();
                assert_eq!(indexing.tokenizer(), "en_stem");
            }
            _ => panic!("expected text field"),
        }
    }
}
