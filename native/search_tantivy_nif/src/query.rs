use rustler::ResourceArc;
use tantivy::query::{
    AllQuery, BooleanQuery, BoostQuery, FuzzyTermQuery, PhrasePrefixQuery, PhraseQuery, QueryClone,
    QueryParser, RegexQuery,
};
use tantivy::schema::IndexRecordOption;
use tantivy::Term;

use crate::error::TantivyNifError;
use crate::index::IndexResource;

pub struct QueryResource {
    pub query: Box<dyn tantivy::query::Query>,
}

unsafe impl Send for QueryResource {}
unsafe impl Sync for QueryResource {}
impl std::panic::RefUnwindSafe for QueryResource {}

#[rustler::resource_impl]
impl rustler::Resource for QueryResource {}

/// Parse a query string.
#[rustler::nif]
fn query_parse(
    index_res: ResourceArc<IndexResource>,
    query_string: String,
    fields: Vec<String>,
) -> Result<ResourceArc<QueryResource>, String> {
    crate::catch_nif_panic! {
        parse_query_internal(&index_res, &query_string, &fields).map_err(|e| e.to_string())
    }
}

/// Create a term query for exact matching on a specific field.
#[rustler::nif]
fn query_term(
    index_res: ResourceArc<IndexResource>,
    field_name: String,
    value: String,
) -> Result<ResourceArc<QueryResource>, String> {
    crate::catch_nif_panic! {
        build_term_query_internal(&index_res, &field_name, &value).map_err(|e| e.to_string())
    }
}

/// Create a boolean query from clauses.
#[rustler::nif]
fn query_boolean(
    clauses: Vec<(String, ResourceArc<QueryResource>)>,
) -> Result<ResourceArc<QueryResource>, String> {
    crate::catch_nif_panic! {
        build_boolean_query_internal(clauses).map_err(|e| e.to_string())
    }
}

/// Create an all-documents query.
#[rustler::nif]
fn query_all() -> Result<ResourceArc<QueryResource>, String> {
    crate::catch_nif_panic! {
        Ok(ResourceArc::new(QueryResource {
            query: Box::new(AllQuery),
        }))
    }
}

/// Boost a query by a factor.
#[rustler::nif]
fn query_boost(
    query_res: ResourceArc<QueryResource>,
    factor: f64,
) -> Result<ResourceArc<QueryResource>, String> {
    crate::catch_nif_panic! {
        let cloned = query_res.query.box_clone();
        Ok(ResourceArc::new(QueryResource {
            query: Box::new(BoostQuery::new(cloned, factor as tantivy::Score)),
        }))
    }
}

/// Create a fuzzy term query for approximate matching.
#[rustler::nif]
fn query_fuzzy_term(
    index_res: ResourceArc<IndexResource>,
    field_name: String,
    value: String,
    distance: u8,
    transpose_costs_one: bool,
) -> Result<ResourceArc<QueryResource>, String> {
    crate::catch_nif_panic! {
        build_fuzzy_term_query_internal(&index_res, &field_name, &value, distance, transpose_costs_one)
            .map_err(|e| e.to_string())
    }
}

/// Create a phrase query for exact phrase matching on a specific field.
#[rustler::nif]
fn query_phrase(
    index_res: ResourceArc<IndexResource>,
    field_name: String,
    words: Vec<String>,
) -> Result<ResourceArc<QueryResource>, String> {
    crate::catch_nif_panic! {
        build_phrase_query_internal(&index_res, &field_name, &words).map_err(|e| e.to_string())
    }
}

/// Create a phrase prefix query (autocomplete-style matching).
#[rustler::nif]
fn query_phrase_prefix(
    index_res: ResourceArc<IndexResource>,
    field_name: String,
    words: Vec<String>,
) -> Result<ResourceArc<QueryResource>, String> {
    crate::catch_nif_panic! {
        build_phrase_prefix_query_internal(&index_res, &field_name, &words).map_err(|e| e.to_string())
    }
}

/// Create a regex query for pattern matching on a specific field.
#[rustler::nif]
fn query_regex(
    index_res: ResourceArc<IndexResource>,
    field_name: String,
    pattern: String,
) -> Result<ResourceArc<QueryResource>, String> {
    crate::catch_nif_panic! {
        build_regex_query_internal(&index_res, &field_name, &pattern).map_err(|e| e.to_string())
    }
}

/// Create an exists query — matches documents where the field has any value.
#[rustler::nif]
fn query_exists(
    index_res: ResourceArc<IndexResource>,
    field_name: String,
) -> Result<ResourceArc<QueryResource>, String> {
    crate::catch_nif_panic! {
        build_exists_query_internal(&index_res, &field_name).map_err(|e| e.to_string())
    }
}

// --- Internal testable functions ---

fn parse_query_internal(
    index_res: &IndexResource,
    query_string: &str,
    fields: &[String],
) -> Result<ResourceArc<QueryResource>, TantivyNifError> {
    let schema = &index_res.schema;

    let default_fields: Vec<tantivy::schema::Field> = if fields.is_empty() {
        schema
            .fields()
            .filter_map(|(field, entry)| {
                if let tantivy::schema::FieldType::Str(_) = entry.field_type() {
                    Some(field)
                } else {
                    None
                }
            })
            .collect()
    } else {
        fields
            .iter()
            .map(|name| {
                schema
                    .get_field(name)
                    .map_err(|_| TantivyNifError::InvalidField(format!("unknown field: {}", name)))
            })
            .collect::<Result<Vec<_>, _>>()?
    };

    let query_parser = QueryParser::for_index(&index_res.index, default_fields);
    let query = query_parser.parse_query(query_string)?;

    Ok(ResourceArc::new(QueryResource { query }))
}

fn build_term_query_internal(
    index_res: &IndexResource,
    field_name: &str,
    value: &str,
) -> Result<ResourceArc<QueryResource>, TantivyNifError> {
    let schema = &index_res.schema;
    let field = schema
        .get_field(field_name)
        .map_err(|_| TantivyNifError::InvalidField(format!("unknown field: {}", field_name)))?;

    let field_entry = schema.get_field_entry(field);
    let term = match field_entry.field_type() {
        tantivy::schema::FieldType::Str(_) => Term::from_field_text(field, value),
        tantivy::schema::FieldType::U64(_) => {
            let parsed: u64 = value.parse().map_err(|_| {
                TantivyNifError::Other(format!("cannot parse '{}' as u64", value))
            })?;
            Term::from_field_u64(field, parsed)
        }
        tantivy::schema::FieldType::I64(_) => {
            let parsed: i64 = value.parse().map_err(|_| {
                TantivyNifError::Other(format!("cannot parse '{}' as i64", value))
            })?;
            Term::from_field_i64(field, parsed)
        }
        tantivy::schema::FieldType::F64(_) => {
            let parsed: f64 = value.parse().map_err(|_| {
                TantivyNifError::Other(format!("cannot parse '{}' as f64", value))
            })?;
            Term::from_field_f64(field, parsed)
        }
        tantivy::schema::FieldType::Bool(_) => {
            let parsed: bool = value.parse().map_err(|_| {
                TantivyNifError::Other(format!("cannot parse '{}' as bool", value))
            })?;
            Term::from_field_bool(field, parsed)
        }
        tantivy::schema::FieldType::Date(_) => {
            let parsed = tantivy::DateTime::from_timestamp_secs(
                chrono::DateTime::parse_from_rfc3339(value)
                    .map_err(|_| {
                        TantivyNifError::Other(format!("cannot parse '{}' as date", value))
                    })?
                    .timestamp(),
            );
            Term::from_field_date(field, parsed)
        }
        tantivy::schema::FieldType::Bytes(_) => Term::from_field_bytes(field, value.as_bytes()),
        tantivy::schema::FieldType::IpAddr(_) => {
            let parsed: std::net::Ipv6Addr =
                if let Ok(v4) = value.parse::<std::net::Ipv4Addr>() {
                    v4.to_ipv6_mapped()
                } else {
                    value.parse().map_err(|_| {
                        TantivyNifError::Other(format!("cannot parse '{}' as IP address", value))
                    })?
                };
            Term::from_field_ip_addr(field, parsed)
        }
        _ => {
            return Err(TantivyNifError::Other(format!(
                "term queries not supported for field type of '{}'",
                field_name
            )));
        }
    };

    Ok(ResourceArc::new(QueryResource {
        query: Box::new(tantivy::query::TermQuery::new(
            term,
            IndexRecordOption::WithFreqs,
        )),
    }))
}

fn build_boolean_query_internal(
    clauses: Vec<(String, ResourceArc<QueryResource>)>,
) -> Result<ResourceArc<QueryResource>, TantivyNifError> {
    let mut tantivy_clauses: Vec<(tantivy::query::Occur, Box<dyn tantivy::query::Query>)> =
        Vec::new();

    for (occur_str, query_res) in &clauses {
        let occur = match occur_str.as_str() {
            "must" => tantivy::query::Occur::Must,
            "should" => tantivy::query::Occur::Should,
            "must_not" => tantivy::query::Occur::MustNot,
            other => {
                return Err(TantivyNifError::Other(format!(
                    "invalid occur type: {}. Expected must, should, or must_not",
                    other
                )))
            }
        };

        let cloned_query = query_res.query.box_clone();
        tantivy_clauses.push((occur, cloned_query));
    }

    Ok(ResourceArc::new(QueryResource {
        query: Box::new(BooleanQuery::new(tantivy_clauses)),
    }))
}

fn build_fuzzy_term_query_internal(
    index_res: &IndexResource,
    field_name: &str,
    value: &str,
    distance: u8,
    transpose_costs_one: bool,
) -> Result<ResourceArc<QueryResource>, TantivyNifError> {
    let schema = &index_res.schema;
    let field = schema
        .get_field(field_name)
        .map_err(|_| TantivyNifError::InvalidField(format!("unknown field: {}", field_name)))?;

    let term = Term::from_field_text(field, &value.to_lowercase());

    Ok(ResourceArc::new(QueryResource {
        query: Box::new(FuzzyTermQuery::new(term, distance, transpose_costs_one)),
    }))
}

fn build_phrase_query_internal(
    index_res: &IndexResource,
    field_name: &str,
    words: &[String],
) -> Result<ResourceArc<QueryResource>, TantivyNifError> {
    let schema = &index_res.schema;
    let field = schema
        .get_field(field_name)
        .map_err(|_| TantivyNifError::InvalidField(format!("unknown field: {}", field_name)))?;

    let terms: Vec<Term> = words
        .iter()
        .map(|w| Term::from_field_text(field, &w.to_lowercase()))
        .collect();

    Ok(ResourceArc::new(QueryResource {
        query: Box::new(PhraseQuery::new(terms)),
    }))
}

fn build_phrase_prefix_query_internal(
    index_res: &IndexResource,
    field_name: &str,
    words: &[String],
) -> Result<ResourceArc<QueryResource>, TantivyNifError> {
    let schema = &index_res.schema;
    let field = schema
        .get_field(field_name)
        .map_err(|_| TantivyNifError::InvalidField(format!("unknown field: {}", field_name)))?;

    let terms: Vec<Term> = words
        .iter()
        .map(|w| Term::from_field_text(field, &w.to_lowercase()))
        .collect();

    Ok(ResourceArc::new(QueryResource {
        query: Box::new(PhrasePrefixQuery::new(terms)),
    }))
}

fn build_regex_query_internal(
    index_res: &IndexResource,
    field_name: &str,
    pattern: &str,
) -> Result<ResourceArc<QueryResource>, TantivyNifError> {
    let schema = &index_res.schema;
    let field = schema
        .get_field(field_name)
        .map_err(|_| TantivyNifError::InvalidField(format!("unknown field: {}", field_name)))?;

    let query = RegexQuery::from_pattern(pattern, field)
        .map_err(|e| TantivyNifError::Other(format!("invalid regex: {}", e)))?;

    Ok(ResourceArc::new(QueryResource {
        query: Box::new(query),
    }))
}

fn build_exists_query_internal(
    index_res: &IndexResource,
    field_name: &str,
) -> Result<ResourceArc<QueryResource>, TantivyNifError> {
    let schema = &index_res.schema;
    let field = schema
        .get_field(field_name)
        .map_err(|_| TantivyNifError::InvalidField(format!("unknown field: {}", field_name)))?;

    // ExistsQuery: matches documents where the field has any indexed value.
    // tantivy doesn't have a built-in ExistsQuery — use a regex that matches anything.
    let query = RegexQuery::from_pattern(".*", field)
        .map_err(|e| TantivyNifError::Other(format!("exists query failed: {}", e)))?;

    Ok(ResourceArc::new(QueryResource {
        query: Box::new(query),
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_all_query() {
        let _q = AllQuery;
    }
}
