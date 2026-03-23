use rustler::ResourceArc;
use tantivy::schema::Schema;
use tantivy::TantivyDocument;

use crate::error::TantivyNifError;
use crate::schema::SchemaResource;

pub struct DocumentResource {
    pub document: TantivyDocument,
}

impl std::panic::RefUnwindSafe for DocumentResource {}

#[rustler::resource_impl]
impl rustler::Resource for DocumentResource {}

/// Create a document from a schema and field-value pairs.
#[rustler::nif]
fn document_create(
    schema_res: ResourceArc<SchemaResource>,
    field_values: Vec<(String, String)>,
) -> Result<ResourceArc<DocumentResource>, String> {
    crate::catch_nif_panic! {
        create_document_internal(&schema_res.schema, &field_values).map_err(|e| e.to_string())
    }
}

fn create_document_internal(
    schema: &Schema,
    field_values: &[(String, String)],
) -> Result<ResourceArc<DocumentResource>, TantivyNifError> {
    let doc = build_document(schema, field_values)?;
    Ok(ResourceArc::new(DocumentResource { document: doc }))
}

fn build_document(
    schema: &Schema,
    field_values: &[(String, String)],
) -> Result<TantivyDocument, TantivyNifError> {
    let mut doc = TantivyDocument::new();

    for (field_name, value) in field_values {
        let field = schema.get_field(field_name).map_err(|_| {
            TantivyNifError::InvalidField(format!("unknown field: {}", field_name))
        })?;

        let field_entry = schema.get_field_entry(field);
        let field_type = field_entry.field_type();

        match field_type {
            tantivy::schema::FieldType::Str(_) => {
                doc.add_text(field, value);
            }
            tantivy::schema::FieldType::U64(_) => {
                let parsed: u64 = value.parse().map_err(|_| {
                    TantivyNifError::Other(format!(
                        "cannot parse '{}' as u64 for field '{}'",
                        value, field_name
                    ))
                })?;
                doc.add_u64(field, parsed);
            }
            tantivy::schema::FieldType::I64(_) => {
                let parsed: i64 = value.parse().map_err(|_| {
                    TantivyNifError::Other(format!(
                        "cannot parse '{}' as i64 for field '{}'",
                        value, field_name
                    ))
                })?;
                doc.add_i64(field, parsed);
            }
            tantivy::schema::FieldType::F64(_) => {
                let parsed: f64 = value.parse().map_err(|_| {
                    TantivyNifError::Other(format!(
                        "cannot parse '{}' as f64 for field '{}'",
                        value, field_name
                    ))
                })?;
                doc.add_f64(field, parsed);
            }
            tantivy::schema::FieldType::Bool(_) => {
                let parsed: bool = value.parse().map_err(|_| {
                    TantivyNifError::Other(format!(
                        "cannot parse '{}' as bool for field '{}'",
                        value, field_name
                    ))
                })?;
                doc.add_bool(field, parsed);
            }
            tantivy::schema::FieldType::Date(_) => {
                let parsed = tantivy::DateTime::from_timestamp_secs(
                    chrono::DateTime::parse_from_rfc3339(value)
                        .map_err(|_| {
                            TantivyNifError::Other(format!(
                                "cannot parse '{}' as date for field '{}'",
                                value, field_name
                            ))
                        })?
                        .timestamp(),
                );
                doc.add_date(field, parsed);
            }
            tantivy::schema::FieldType::Bytes(_) => {
                doc.add_bytes(field, value.as_bytes());
            }
            tantivy::schema::FieldType::JsonObject(_) => {
                let json_val: serde_json::Value =
                    serde_json::from_str(value).map_err(|e| {
                        TantivyNifError::Other(format!(
                            "cannot parse JSON for field '{}': {}",
                            field_name, e
                        ))
                    })?;
                let owned = json_to_owned_value(&json_val);
                doc.add_field_value(field, &owned);
            }
            tantivy::schema::FieldType::IpAddr(_) => {
                let parsed: std::net::Ipv6Addr =
                    if let Ok(v4) = value.parse::<std::net::Ipv4Addr>() {
                        v4.to_ipv6_mapped()
                    } else {
                        value.parse().map_err(|_| {
                            TantivyNifError::Other(format!(
                                "cannot parse '{}' as IP address for field '{}'",
                                value, field_name
                            ))
                        })?
                    };
                doc.add_ip_addr(field, parsed);
            }
            tantivy::schema::FieldType::Facet(_) => {
                let facet = tantivy::schema::Facet::from_text(value).map_err(|e| {
                    TantivyNifError::Other(format!(
                        "cannot parse '{}' as facet for field '{}': {}",
                        value, field_name, e
                    ))
                })?;
                doc.add_facet(field, facet);
            }
        }
    }

    Ok(doc)
}

fn json_to_owned_value(val: &serde_json::Value) -> tantivy::schema::OwnedValue {
    match val {
        serde_json::Value::Null => tantivy::schema::OwnedValue::Null,
        serde_json::Value::Bool(b) => tantivy::schema::OwnedValue::Bool(*b),
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                tantivy::schema::OwnedValue::I64(i)
            } else if let Some(u) = n.as_u64() {
                tantivy::schema::OwnedValue::U64(u)
            } else if let Some(f) = n.as_f64() {
                tantivy::schema::OwnedValue::F64(f)
            } else {
                tantivy::schema::OwnedValue::Null
            }
        }
        serde_json::Value::String(s) => tantivy::schema::OwnedValue::Str(s.clone()),
        serde_json::Value::Array(arr) => {
            tantivy::schema::OwnedValue::Array(arr.iter().map(json_to_owned_value).collect())
        }
        serde_json::Value::Object(map) => {
            let entries: Vec<(String, tantivy::schema::OwnedValue)> = map
                .iter()
                .map(|(k, v)| (k.clone(), json_to_owned_value(v)))
                .collect();
            tantivy::schema::OwnedValue::Object(entries)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tantivy::schema::{SchemaBuilder, TEXT, STORED};

    #[test]
    fn test_create_text_document() {
        let mut builder = SchemaBuilder::default();
        builder.add_text_field("title", TEXT | STORED);
        let schema = builder.build();

        let field_values = vec![("title".to_string(), "Hello World".to_string())];
        let result = build_document(&schema, &field_values);
        assert!(result.is_ok());
    }

    #[test]
    fn test_invalid_field_name() {
        let mut builder = SchemaBuilder::default();
        builder.add_text_field("title", TEXT | STORED);
        let schema = builder.build();

        let field_values = vec![("nonexistent".to_string(), "value".to_string())];
        let result = build_document(&schema, &field_values);
        assert!(result.is_err());
    }
}
