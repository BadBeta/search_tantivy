use rustler::ResourceArc;
use tantivy::aggregation::agg_req::Aggregations;
use tantivy::aggregation::AggregationCollector;
use tantivy::aggregation::AggregationLimitsGuard;
use tantivy::collector::TopDocs;
use tantivy::TantivyDocument;

use crate::error::TantivyNifError;
use crate::index::ReaderResource;
use crate::query::QueryResource;

/// A single search result: `(score, [(field_name, field_value)])`.
type SearchResult = (f32, Vec<(String, String)>);

/// Execute a search query and return scored results.
#[rustler::nif(schedule = "DirtyCpu")]
fn search(
    reader_res: ResourceArc<ReaderResource>,
    query_res: ResourceArc<QueryResource>,
    limit: usize,
    offset: usize,
) -> Result<Vec<SearchResult>, String> {
    crate::catch_nif_panic! {
        search_internal(&reader_res, &query_res, limit, offset).map_err(|e| e.to_string())
    }
}

/// Execute a search with aggregations and return JSON result.
///
/// Takes an aggregation request as a JSON string (Elasticsearch-compatible format)
/// and returns the aggregation results as a JSON string.
#[rustler::nif(schedule = "DirtyCpu")]
fn search_with_aggs(
    reader_res: ResourceArc<ReaderResource>,
    query_res: ResourceArc<QueryResource>,
    agg_json: String,
) -> Result<String, String> {
    crate::catch_nif_panic! {
        search_with_aggs_internal(&reader_res, &query_res, &agg_json).map_err(|e| e.to_string())
    }
}

fn search_with_aggs_internal(
    reader_res: &ReaderResource,
    query_res: &QueryResource,
    agg_json: &str,
) -> Result<String, TantivyNifError> {
    let agg_req: Aggregations = serde_json::from_str(agg_json)
        .map_err(|e| TantivyNifError::Other(format!("invalid aggregation JSON: {}", e)))?;

    let collector = AggregationCollector::from_aggs(agg_req, AggregationLimitsGuard::default());
    let searcher = reader_res.reader.searcher();
    let agg_result = searcher.search(&*query_res.query, &collector)?;

    let result_json = serde_json::to_string(&agg_result)
        .map_err(|e| TantivyNifError::Other(format!("failed to serialize agg result: {}", e)))?;

    Ok(result_json)
}

fn search_internal(
    reader_res: &ReaderResource,
    query_res: &QueryResource,
    limit: usize,
    offset: usize,
) -> Result<Vec<SearchResult>, TantivyNifError> {
    let searcher = reader_res.reader.searcher();
    let collector = TopDocs::with_limit(limit).and_offset(offset);
    let top_docs = searcher.search(&*query_res.query, &collector)?;

    let mut results = Vec::with_capacity(top_docs.len());
    for (score, doc_address) in top_docs {
        let doc: TantivyDocument = searcher.doc(doc_address)?;
        let field_pairs = doc_to_field_pairs(&reader_res.schema, &doc);
        results.push((score, field_pairs));
    }

    Ok(results)
}

pub fn doc_to_field_pairs(
    schema: &tantivy::schema::Schema,
    doc: &TantivyDocument,
) -> Vec<(String, String)> {
    let mut pairs = Vec::new();

    for (field, value) in doc.field_values() {
        let field_name = schema.get_field_name(field).to_string();
        let value_str = compact_value_to_string(&value);
        pairs.push((field_name, value_str));
    }

    pairs
}

fn compact_value_to_string(value: &tantivy::schema::document::CompactDocValue<'_>) -> String {
    use tantivy::schema::Value;
    if let Some(s) = value.as_str() {
        s.to_string()
    } else if let Some(n) = value.as_u64() {
        n.to_string()
    } else if let Some(n) = value.as_i64() {
        n.to_string()
    } else if let Some(n) = value.as_f64() {
        n.to_string()
    } else if let Some(b) = value.as_bool() {
        b.to_string()
    } else if let Some(d) = value.as_datetime() {
        format!("{:?}", d)
    } else if let Some(b) = value.as_bytes() {
        format!("{:?}", b)
    } else {
        format!("{:?}", value)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tantivy::schema::{SchemaBuilder, TEXT, STORED};
    use tantivy::{Index, TantivyDocument};

    #[test]
    fn test_search_empty_index() {
        let mut builder = SchemaBuilder::default();
        builder.add_text_field("title", TEXT | STORED);
        let schema = builder.build();

        let index = Index::create_in_ram(schema.clone());
        let mut writer: tantivy::IndexWriter<TantivyDocument> = index.writer(15_000_000).unwrap();
        writer.commit().unwrap();

        let reader = index.reader().unwrap();
        let reader_res = ReaderResource { reader, schema };
        let query_res = QueryResource {
            query: Box::new(tantivy::query::AllQuery),
        };

        let results = search_internal(&reader_res, &query_res, 10, 0).unwrap();
        assert!(results.is_empty());
    }

    #[test]
    fn test_search_with_documents() {
        let mut builder = SchemaBuilder::default();
        let title = builder.add_text_field("title", TEXT | STORED);
        let schema = builder.build();

        let index = Index::create_in_ram(schema.clone());
        let mut writer: tantivy::IndexWriter<TantivyDocument> = index.writer(15_000_000).unwrap();

        let mut doc = TantivyDocument::new();
        doc.add_text(title, "Hello World");
        writer.add_document(doc).unwrap();
        writer.commit().unwrap();

        let reader = index.reader().unwrap();
        let reader_res = ReaderResource {
            reader,
            schema: schema.clone(),
        };

        let query_parser = tantivy::query::QueryParser::for_index(&index, vec![title]);
        let query = query_parser.parse_query("hello").unwrap();
        let query_res = QueryResource { query };

        let results = search_internal(&reader_res, &query_res, 10, 0).unwrap();
        assert_eq!(results.len(), 1);
        assert!(results[0].0 > 0.0);

        let field_pairs = &results[0].1;
        assert!(field_pairs
            .iter()
            .any(|(k, v)| k == "title" && v == "Hello World"));
    }
}
