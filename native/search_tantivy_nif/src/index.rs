use parking_lot::RwLock;
use rustler::ResourceArc;
use tantivy::schema::Schema;
use tantivy::{Index, IndexReader, IndexWriter};

use crate::error::TantivyNifError;
use crate::schema::SchemaResource;

pub struct IndexResource {
    pub index: Index,
    pub schema: Schema,
}

impl std::panic::RefUnwindSafe for IndexResource {}

#[rustler::resource_impl]
impl rustler::Resource for IndexResource {}

pub struct WriterResource {
    pub writer: RwLock<IndexWriter>,
}

impl std::panic::RefUnwindSafe for WriterResource {}

#[rustler::resource_impl]
impl rustler::Resource for WriterResource {}

pub struct ReaderResource {
    pub reader: IndexReader,
    pub schema: Schema,
}

impl std::panic::RefUnwindSafe for ReaderResource {}

#[rustler::resource_impl]
impl rustler::Resource for ReaderResource {}

/// Create a new index at a directory path.
#[rustler::nif(schedule = "DirtyIo")]
fn index_create(
    schema_res: ResourceArc<SchemaResource>,
    path: String,
) -> Result<ResourceArc<IndexResource>, String> {
    crate::catch_nif_panic! {
        create_index_at_path(&schema_res.schema, &path).map_err(|e| e.to_string())
    }
}

/// Create a new in-memory (RAM) index.
#[rustler::nif]
fn index_create_in_ram(
    schema_res: ResourceArc<SchemaResource>,
) -> Result<ResourceArc<IndexResource>, String> {
    crate::catch_nif_panic! {
        let index = Index::create_in_ram(schema_res.schema.clone());
        Ok(ResourceArc::new(IndexResource {
            schema: schema_res.schema.clone(),
            index,
        }))
    }
}

/// Open an existing index from a directory path.
#[rustler::nif(schedule = "DirtyIo")]
fn index_open(path: String) -> Result<ResourceArc<IndexResource>, String> {
    crate::catch_nif_panic! {
        open_index_at_path(&path).map_err(|e| e.to_string())
    }
}

/// Create a new IndexWriter with the given memory budget.
#[rustler::nif]
fn index_writer_new(
    index_res: ResourceArc<IndexResource>,
    memory_budget: usize,
) -> Result<ResourceArc<WriterResource>, String> {
    crate::catch_nif_panic! {
        let writer = index_res
            .index
            .writer(memory_budget)
            .map_err(|e| e.to_string())?;

        Ok(ResourceArc::new(WriterResource {
            writer: RwLock::new(writer),
        }))
    }
}

/// Create a new IndexReader from an index.
#[rustler::nif]
fn index_reader(
    index_res: ResourceArc<IndexResource>,
) -> Result<ResourceArc<ReaderResource>, String> {
    crate::catch_nif_panic! {
        let reader = index_res
            .index
            .reader()
            .map_err(|e| e.to_string())?;

        Ok(ResourceArc::new(ReaderResource {
            reader,
            schema: index_res.schema.clone(),
        }))
    }
}

/// Add a document to the writer.
#[rustler::nif]
fn writer_add_document(
    writer_res: ResourceArc<WriterResource>,
    doc_res: ResourceArc<crate::document::DocumentResource>,
) -> Result<(), String> {
    crate::catch_nif_panic! {
        let guard = writer_res
            .writer
            .try_write()
            .ok_or_else(|| "writer lock contention — retry".to_string())?;

        guard
            .add_document(doc_res.document.clone())
            .map_err(|e| e.to_string())?;

        Ok(())
    }
}

/// Delete documents matching a term.
#[rustler::nif]
fn writer_delete_documents(
    writer_res: ResourceArc<WriterResource>,
    field_name: String,
    value: String,
) -> Result<(), String> {
    crate::catch_nif_panic! {
        let guard = writer_res
            .writer
            .try_write()
            .ok_or_else(|| "writer lock contention — retry".to_string())?;

        let schema = guard.index().schema();
        let field = schema
            .get_field(&field_name)
            .map_err(|_| format!("unknown field: {}", field_name))?;

        let term = tantivy::Term::from_field_text(field, &value);
        guard.delete_term(term);

        Ok(())
    }
}

/// Commit pending changes.
#[rustler::nif(schedule = "DirtyCpu")]
fn writer_commit(
    writer_res: ResourceArc<WriterResource>,
) -> Result<u64, String> {
    crate::catch_nif_panic! {
        let mut guard = writer_res
            .writer
            .try_write()
            .ok_or_else(|| "writer lock contention — retry".to_string())?;

        let opstamp = guard.commit().map_err(|e| e.to_string())?;
        Ok(opstamp)
    }
}

// --- Internal testable functions ---

fn create_index_at_path(
    schema: &Schema,
    path: &str,
) -> Result<ResourceArc<IndexResource>, TantivyNifError> {
    std::fs::create_dir_all(path)?;
    let dir = tantivy::directory::MmapDirectory::open(path)?;
    let index = Index::open_or_create(dir, schema.clone())?;
    Ok(ResourceArc::new(IndexResource {
        schema: schema.clone(),
        index,
    }))
}

fn open_index_at_path(path: &str) -> Result<ResourceArc<IndexResource>, TantivyNifError> {
    let dir = tantivy::directory::MmapDirectory::open(path)?;
    let index = Index::open(dir)?;
    let schema = index.schema();
    Ok(ResourceArc::new(IndexResource { schema, index }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tantivy::schema::{SchemaBuilder, TEXT, STORED};

    fn test_schema() -> Schema {
        let mut builder = SchemaBuilder::default();
        builder.add_text_field("title", TEXT | STORED);
        builder.build()
    }

    #[test]
    fn test_create_ram_index() {
        let schema = test_schema();
        let index = Index::create_in_ram(schema.clone());
        assert!(index.schema().get_field("title").is_ok());
    }

    #[test]
    fn test_create_disk_index() {
        let schema = test_schema();
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().to_str().unwrap();
        // Test the underlying tantivy operations directly (ResourceArc needs BEAM runtime)
        std::fs::create_dir_all(path).unwrap();
        let dir = tantivy::directory::MmapDirectory::open(path).unwrap();
        let index = Index::open_or_create(dir, schema).unwrap();
        assert!(index.schema().get_field("title").is_ok());
    }
}
