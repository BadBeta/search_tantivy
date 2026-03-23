use rustler::ResourceArc;
use tantivy::collector::TopDocs;
use tantivy::snippet::SnippetGenerator;
use tantivy::TantivyDocument;

use crate::error::TantivyNifError;
use crate::index::ReaderResource;
use crate::query::QueryResource;

/// A search result with snippets: `(score, [(field_name, value)], [(field_name, html_snippet)])`.
type SnippetResult = (f32, Vec<(String, String)>, Vec<(String, String)>);

/// Search with snippet generation for highlighted results.
///
/// Returns `Vec<(score, field_pairs, snippet_pairs)>` where snippet_pairs
/// contains `(field_name, highlighted_html)` for each requested field.
#[rustler::nif(schedule = "DirtyCpu")]
fn search_with_snippets(
    reader_res: ResourceArc<ReaderResource>,
    query_res: ResourceArc<QueryResource>,
    limit: usize,
    offset: usize,
    snippet_fields: Vec<String>,
) -> Result<Vec<SnippetResult>, String> {
    crate::catch_nif_panic! {
        search_with_snippets_internal(&reader_res, &query_res, limit, offset, &snippet_fields)
            .map_err(|e| e.to_string())
    }
}

fn search_with_snippets_internal(
    reader_res: &ReaderResource,
    query_res: &QueryResource,
    limit: usize,
    offset: usize,
    snippet_fields: &[String],
) -> Result<Vec<SnippetResult>, TantivyNifError> {
    let schema = &reader_res.schema;
    let searcher = reader_res.reader.searcher();
    let collector = TopDocs::with_limit(limit).and_offset(offset);
    let top_docs = searcher.search(&*query_res.query, &collector)?;

    // Build snippet generators for each requested field
    let snippet_generators: Vec<(String, SnippetGenerator)> = snippet_fields
        .iter()
        .filter_map(|field_name| {
            let field = schema.get_field(field_name).ok()?;
            let generator =
                SnippetGenerator::create(&searcher, &*query_res.query, field).ok()?;
            Some((field_name.clone(), generator))
        })
        .collect();

    let mut results = Vec::with_capacity(top_docs.len());
    for (score, doc_address) in top_docs {
        let doc: TantivyDocument = searcher.doc(doc_address)?;
        let field_pairs = crate::search::doc_to_field_pairs(schema, &doc);

        let snippets: Vec<(String, String)> = snippet_generators
            .iter()
            .map(|(field_name, generator)| {
                let snippet = generator.snippet_from_doc(&doc);
                let html = snippet.to_html();
                (field_name.clone(), html)
            })
            .collect();

        results.push((score, field_pairs, snippets));
    }

    Ok(results)
}

/// Register a built-in tokenizer on an index.
///
/// Supports language-specific analyzers (e.g., "en_stem", "fr_stem", "de_stem")
/// and basic tokenizers ("default", "raw", "whitespace").
#[rustler::nif]
fn tokenizer_register(
    index_res: ResourceArc<crate::index::IndexResource>,
    tokenizer_name: String,
) -> Result<(), String> {
    crate::catch_nif_panic! {
        register_tokenizer_internal(&index_res, &tokenizer_name).map_err(|e| e.to_string())
    }
}

fn register_tokenizer_internal(
    index_res: &crate::index::IndexResource,
    tokenizer_name: &str,
) -> Result<(), TantivyNifError> {
    use tantivy::tokenizer::*;

    let tokenizer_manager = index_res.index.tokenizers();

    // Built-in tokenizers ("default", "raw") are already registered by tantivy.
    // We handle language-specific stemming analyzers and custom pipelines.
    let analyzer: Option<TextAnalyzer> = match tokenizer_name {
        "default" | "raw" => None, // Already registered
        "whitespace" => Some(TextAnalyzer::builder(WhitespaceTokenizer::default()).build()),
        "en_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::English))
                .build(),
        ),
        "fr_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::French))
                .build(),
        ),
        "de_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::German))
                .build(),
        ),
        "es_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Spanish))
                .build(),
        ),
        "pt_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Portuguese))
                .build(),
        ),
        "it_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Italian))
                .build(),
        ),
        "nl_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Dutch))
                .build(),
        ),
        "sv_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Swedish))
                .build(),
        ),
        "no_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Norwegian))
                .build(),
        ),
        "da_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Danish))
                .build(),
        ),
        "fi_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Finnish))
                .build(),
        ),
        "hu_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Hungarian))
                .build(),
        ),
        "ro_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Romanian))
                .build(),
        ),
        "ru_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Russian))
                .build(),
        ),
        "tr_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Turkish))
                .build(),
        ),
        "ar_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Arabic))
                .build(),
        ),
        "ta_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Tamil))
                .build(),
        ),
        "el_stem" => Some(
            TextAnalyzer::builder(SimpleTokenizer::default())
                .filter(RemoveLongFilter::limit(40))
                .filter(LowerCaser)
                .filter(Stemmer::new(Language::Greek))
                .build(),
        ),
        other => {
            return Err(TantivyNifError::Other(format!(
                "unknown tokenizer: '{}'. Available: default, raw, whitespace, \
                 en_stem, fr_stem, de_stem, es_stem, pt_stem, it_stem, nl_stem, \
                 sv_stem, no_stem, da_stem, fi_stem, hu_stem, ro_stem, ru_stem, \
                 tr_stem, ar_stem, ta_stem, el_stem",
                other
            )));
        }
    };

    if let Some(analyzer) = analyzer {
        tokenizer_manager.register(tokenizer_name, analyzer);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tantivy::query::QueryParser;
    use tantivy::schema::{SchemaBuilder, STORED, TEXT};
    use tantivy::Index;

    #[test]
    fn test_search_with_snippets() {
        let mut builder = SchemaBuilder::default();
        let title = builder.add_text_field("title", TEXT | STORED);
        let body = builder.add_text_field("body", TEXT | STORED);
        let schema = builder.build();

        let index = Index::create_in_ram(schema.clone());
        let mut writer: tantivy::IndexWriter<TantivyDocument> =
            index.writer(15_000_000).unwrap();

        let mut doc = TantivyDocument::new();
        doc.add_text(title, "Elixir Programming");
        doc.add_text(body, "Elixir is a functional programming language built on the BEAM");
        writer.add_document(doc).unwrap();
        writer.commit().unwrap();

        let reader = index.reader().unwrap();
        let reader_res = ReaderResource {
            reader,
            schema: schema.clone(),
        };

        let query_parser = QueryParser::for_index(&index, vec![title, body]);
        let query = query_parser.parse_query("elixir").unwrap();
        let query_res = QueryResource { query };

        let results = search_with_snippets_internal(
            &reader_res,
            &query_res,
            10,
            0,
            &["title".to_string(), "body".to_string()],
        )
        .unwrap();

        assert_eq!(results.len(), 1);
        let (score, _fields, snippets) = &results[0];
        assert!(*score > 0.0);
        assert_eq!(snippets.len(), 2);

        // Snippets should contain <b> tags around matched terms
        let body_snippet = snippets.iter().find(|(k, _)| k == "body").unwrap();
        assert!(
            body_snippet.1.contains("<b>"),
            "Expected highlighted snippet, got: {}",
            body_snippet.1
        );
    }

    #[test]
    fn test_search_with_no_snippet_fields() {
        let mut builder = SchemaBuilder::default();
        let title = builder.add_text_field("title", TEXT | STORED);
        let schema = builder.build();

        let index = Index::create_in_ram(schema.clone());
        let mut writer: tantivy::IndexWriter<TantivyDocument> =
            index.writer(15_000_000).unwrap();

        let mut doc = TantivyDocument::new();
        doc.add_text(title, "Hello World");
        writer.add_document(doc).unwrap();
        writer.commit().unwrap();

        let reader = index.reader().unwrap();
        let reader_res = ReaderResource {
            reader,
            schema: schema.clone(),
        };

        let query_parser = QueryParser::for_index(&index, vec![title]);
        let query = query_parser.parse_query("hello").unwrap();
        let query_res = QueryResource { query };

        let results =
            search_with_snippets_internal(&reader_res, &query_res, 10, 0, &[]).unwrap();

        assert_eq!(results.len(), 1);
        let (_, _, snippets) = &results[0];
        assert!(snippets.is_empty());
    }
}
